// Copyright 2017 Esri.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ArcGIS

class ReadGeopackageViewController: NSViewController {
    @IBOutlet weak var mapView: AGSMapView!
    
    @IBOutlet weak var layersInMapTableView: NSTableView!
    @IBOutlet weak var layersNotInMapTableView: NSTableView!
    
    private let layerInMapPasteboardType = NSPasteboard.PasteboardType("AGSLayerInMap")
    
    fileprivate var allLayers: [AGSLayer] = [] {
        didSet {
            var rasterCount = 1
            for layer in allLayers where layer is AGSRasterLayer &&
                layer.name.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                    // Give raster layers a name
                    layer.name = "Raster Layer \(rasterCount)"
                    rasterCount += 1
            }
        }
    }
    
    fileprivate var layersInMap: [AGSLayer] {
        // 0 is the bottom-most layer on the map, but first cell in a table.
        // By reversing the layer order from the map, we match the NSTableView order.
        return mapView.map?.operationalLayers.reversed() as? [AGSLayer] ?? []
    }
    
    fileprivate var layersNotInMap: [AGSLayer] {
        guard mapView.map != nil else {
            return allLayers
        }
        
        return allLayers.filter { !layersInMap.contains($0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Instantiate and display a map using a basemap, location, and zoom level.
        mapView.map = AGSMap(basemapType: .streets, latitude: 39.7294, longitude: -104.8319, levelOfDetail: 11)
        
        // Create a geopackage from a named bundle resource.
        let geoPackage = AGSGeoPackage(name: "AuroraCO")
        
        // Load the geopackage.
        geoPackage.load { [weak self] error in
            guard let self = self else {
                return
            }
            
            if let error = error {
                print("Error loading the geopackage: \(error.localizedDescription)")
            } else {
                // Create feature layers for each feature table in the geopackage.
                let featureLayers = geoPackage.geoPackageFeatureTables.map { AGSFeatureLayer(featureTable: $0) }
                
                // Create raster layers for each raster in the geopackage.
                let rasterLayers = geoPackage.geoPackageRasters.map({ raster -> AGSLayer in
                    let rasterLayer = AGSRasterLayer(raster: raster)
                    //make layer semi-transparent so it doesn't obscure the contents underneath it
                    rasterLayer.opacity = 0.55
                    return rasterLayer
                })
                
                // Keep an array of all the feature layers and raster layers in this geopackage.
                var layers = [AGSLayer]()
                layers.append(contentsOf: rasterLayers)
                layers.append(contentsOf: featureLayers)
                self.allLayers = layers
                
                self.layersInMapTableView.reloadData()
                self.layersNotInMapTableView.reloadData()
            }
        }
        
        // Enable us to drag layers to reorder them in the table view.
        layersInMapTableView.registerForDraggedTypes([layerInMapPasteboardType])
    }
}

extension ReadGeopackageViewController: NSTableViewDataSource, NSTableViewDelegate, GPKGLayerTableCellDelegate {
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        // Return how many layers to show in each table
        if tableView == self.layersInMapTableView {
            return layersInMap.count
        } else {
            return layersNotInMap.count
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == self.layersInMapTableView {
            // Get a row to show a layer that is in the map.
            if let rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("AddedLayerRowView"), owner: self) as? GPKGLayerTableCell {
                rowView.agsLayer = layersInMap[row]
                rowView.delegate = self
                return rowView
            }
        } else {
            // Get a row to show a layer that is not in the map.
            if let rowView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("RemovedLayerRowView"), owner: self) as? NSTableCellView {
                let layer = layersNotInMap[row]
                rowView.textField?.stringValue = layer.name
                return rowView
            }
        }
        print("Unable to create tableview row view!")
        return nil
    }
    
    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pboard: NSPasteboard) -> Bool {
        if tableView == layersInMapTableView {
            let data = NSKeyedArchiver.archivedData(withRootObject: [rowIndexes])
            pboard.declareTypes([layerInMapPasteboardType], owner: self)
            pboard.setData(data, forType: layerInMapPasteboardType)
            
            return true
        } else {
            return false
        }
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if tableView == layersInMapTableView {
            tableView.setDropRow(row, dropOperation: NSTableView.DropOperation.above)
            return .move
        } else {
            return NSDragOperation()
        }
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let pasteboard = info.draggingPasteboard
        let rowData = pasteboard.data(forType: layerInMapPasteboardType)
        
        if rowData != nil {
            // A row for a layer in the map was dragged and dropped. Let's re-order the map layers to match.
            let dataArray = NSKeyedUnarchiver.unarchiveObject(with: rowData!) as! [IndexSet]
            
            if let movingFromIndex = dataArray.first?.first {
                self.moveLayer(fromIndex: movingFromIndex, toIndex: row)
            
                return true
            }
            return false
        } else {
            return false
        }
    }
    
    func moveLayer(fromIndex: Int, toIndex: Int) {
        guard let map = mapView.map else {
            print("No map to manipulate layers on!")
            return
        }
        
        guard fromIndex != toIndex && toIndex != fromIndex + 1 else {
            // Don't do anything if we drop it into the gap between itself and
            // the row before or itself and the row after.
            return
        }
        
        // Figure out which layer was moved and where it was moved to.
        let newMapIndex = map.operationalLayers.count - toIndex
        let layer = layersInMap[fromIndex]

        // Remove the layer, and re-add it in the new layer order.
        map.operationalLayers.remove(layer)
        map.operationalLayers.insert(layer, at: newMapIndex)

        // And redraw the table view to reflect the move.
        layersInMapTableView.reloadData()
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let tableView = notification.object as? NSTableView {
            if tableView == layersNotInMapTableView, tableView.selectedRow != -1 {
                // Clicked to add a layer to the map.
                let layer = layersNotInMap[tableView.selectedRow]
                mapView.map?.operationalLayers.add(layer)
                
                // Redraw the table views for layers in the map and layers not in the map.
                layersInMapTableView.reloadData()
                layersNotInMapTableView.reloadData()
            }
        }
    }
    
    // MARK: - GPKGLayerTableCellDelegate
    
    func removeLayerFromMap(cell: GPKGLayerTableCell) {
        // The trash can was clicked in a cell for a layer that's on the map.
        if let layer = cell.agsLayer {
            // Remove it from the map.
            mapView.map?.operationalLayers.remove(layer)

            // Redraw the table views for layers in the map and layers not in the map.
            layersInMapTableView.reloadData()
            layersNotInMapTableView.reloadData()
        }
    }
}
