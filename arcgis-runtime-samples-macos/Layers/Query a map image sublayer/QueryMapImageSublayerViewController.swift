//
// Copyright © 2018 Esri.
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
//

import AppKit
import ArcGIS

class QueryMapImageSublayerViewController: NSViewController {
    /// The map displayed in the map view.
    let map: AGSMap
    let imageLayer: AGSArcGISMapImageLayer
    let graphicsOverlay: AGSGraphicsOverlay
    
    required init?(coder: NSCoder) {
        map = AGSMap(basemap: .streetsVector())
        
        // Set the initial viewpoint.
        let center = AGSPoint(x: -12716000.00, y: 4170400.00, spatialReference: .webMercator())
        map.initialViewpoint = AGSViewpoint(center: center, scale: 6000000)
        
        // Create an image layer and add it to the map.
        imageLayer = AGSArcGISMapImageLayer(url: .unitedStatesMapService)
        map.operationalLayers.add(imageLayer)
        
        // Create the graphics overlay.
        graphicsOverlay = AGSGraphicsOverlay()
        
        super.init(coder: coder)
        
        // Begin loading the image layer.
        imageLayer.load { [weak self] (error) in
            if let error = error {
                self?.layerDidFailToLoad(with: error)
            } else {
                self?.layerDidLoad()
            }
        }
    }
    
    /// The map view managed by the view controller.
    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet weak var populationTextField: NSTextField!
    @IBOutlet weak var queryButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assign the map to the map view.
        mapView.map = map
        
        // Add the graphics overlay to the map view.
        mapView.graphicsOverlays.add(graphicsOverlay)
        
        enableControlsIfNeeded()
    }
    
    /// Called in response to the layer loading successfully.
    func layerDidLoad() {
        imageLayer.mapImageSublayers.forEach { ($0 as? AGSArcGISMapImageSublayer)?.load() }
        enableControlsIfNeeded()
    }
    
    /// Called in response to the layer failing to load. Presents an alert
    /// announcing the failure.
    ///
    /// - Parameter error: The error that caused loading to fail.
    func layerDidFailToLoad(with error: Error) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Failed to load ArcGIS map image layer"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
    
    var citiesTable: AGSServiceFeatureTable? {
        return (imageLayer.mapImageSublayers[0] as? AGSArcGISMapImageSublayer)?.table
    }
    
    var statesTable: AGSServiceFeatureTable? {
        return (imageLayer.mapImageSublayers[2] as? AGSArcGISMapImageSublayer)?.table
    }
    
    var countiesTable: AGSServiceFeatureTable? {
        return (imageLayer.mapImageSublayers[3] as? AGSArcGISMapImageSublayer)?.table
    }
    
    /// Enables the text field and button if they can be enabled and haven't
    /// been already.
    func enableControlsIfNeeded() {
        guard isViewLoaded, imageLayer.loadStatus == .loaded else { return }
        populationTextField.isEnabled = true
        populationTextField.window?.makeFirstResponder(populationTextField)
        queryButton.isEnabled = true
    }
    
    /// The number formatter used to convert the user input string to a number.
    let numberFormatter = NumberFormatter()
    
    @IBAction func query(_ sender: Any) {
        populationTextField.window?.makeFirstResponder(mapView)
        let trimmedString = populationTextField.stringValue.trimmingCharacters(in: .whitespaces)
        if let value = numberFormatter.number(from: trimmedString) {
            populationValue = value.intValue
        } else if trimmedString.isEmpty {
            populationValue = nil
        } else {
            let alert = NSAlert()
            alert.messageText = "The population value must be numeric."
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: self.view.window!)
        }
    }
    
    /// The population value provided by the user.
    var populationValue: Int? {
        didSet {
            populationValueDidChange()
        }
    }
    
    /// Called in response to the population value changing.
    func populationValueDidChange() {
        graphicsOverlay.graphics.removeAllObjects()
        
        guard let populationValue = populationValue else { return }
        
        let populationQuery = AGSQueryParameters()
        populationQuery.whereClause = "POP2000 > \(populationValue)"
        populationQuery.geometry = mapView.currentViewpoint(with: .boundingGeometry)?.targetGeometry
        
        for table in [citiesTable, statesTable, countiesTable] {
            table?.queryFeatures(with: populationQuery) { [weak self, weak table] (result, error) in
                guard let featureTable = table else { return }
                if let result = result {
                    self?.featureTable(featureTable, featureQueryDidSucceedWith: result)
                } else if let error = error {
                    self?.featureTable(featureTable, featureQueryDidFailWith: error)
                }
            }
        }
    }
    
    /// Called when a feature query of a feature table finishes successfully.
    ///
    /// - Parameters:
    ///   - featureTable: The feature table that was queried.
    ///   - result: The feature query result.
    func featureTable(_ featureTable: AGSFeatureTable, featureQueryDidSucceedWith result: AGSFeatureQueryResult) {
        let symbol = makeSymbol(featureTable: featureTable)
        let graphics: [AGSGraphic] = result.featureEnumerator().map {
            AGSGraphic(geometry: ($0 as! AGSFeature).geometry, symbol: symbol, attributes: nil)
        }
        graphicsOverlay.graphics.addObjects(from: graphics)
    }
    
    /// Called when a feature query of a feature table is unsuccessful.
    ///
    /// - Parameters:
    ///   - featureTable: The feature table that was queried.
    ///   - error: The error that caused the query to fail.
    func featureTable(_ featureTable: AGSFeatureTable, featureQueryDidFailWith error: Error) {
        print("\(featureTable.tableName) feature query failed: \(error)")
    }
    
    /// Creates a symbol for features of the given feature table.
    ///
    /// - Parameter featureTable: A feature table.
    /// - Returns: An `AGSSymbol` object.
    func makeSymbol(featureTable: AGSFeatureTable) -> AGSSymbol? {
        switch featureTable {
        case citiesTable:
            return AGSSimpleMarkerSymbol(style: .circle, color: .red, size: 16)
        case statesTable:
            let outline = AGSSimpleLineSymbol(style: .solid, color: #colorLiteral(red: 0, green: 0.5450980392, blue: 0.5450980392, alpha: 1), width: 6)
            return AGSSimpleFillSymbol(style: .null, color: .cyan, outline: outline)
        case countiesTable:
            let outline = AGSSimpleLineSymbol(style: .dash, color: .cyan, width: 2)
            return AGSSimpleFillSymbol(style: .diagonalCross, color: .cyan, outline: outline)
        default:
            return nil
        }
    }
}
