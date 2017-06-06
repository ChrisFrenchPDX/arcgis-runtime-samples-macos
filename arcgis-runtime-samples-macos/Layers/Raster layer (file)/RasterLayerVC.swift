//
//  RasterLayerVC.swift
//  arcgis-runtime-samples-macos
//
//  Created by Sarat Karumuri on 6/5/17.
//  Copyright © 2017 Esri. All rights reserved.
//

import Cocoa
import ArcGIS

class RasterLayerVC: NSViewController {

    @IBOutlet private weak var mapView: AGSMapView!
    
    private var rasterLayer: AGSRasterLayer!
    
    private var map:AGSMap!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let raster = AGSRaster(name: "Shasta", extension: "tif")
        
        //create raster layer using raster
        self.rasterLayer = AGSRasterLayer(raster: raster)
        
        //initialize map with raster layer as the basemap
        self.map = AGSMap(basemap: AGSBasemap.imagery())
        
        self.mapView.map = map
        
        self.mapView.map?.operationalLayers.add(rasterLayer!)
        
        self.rasterLayer.addObserver(self, forKeyPath: "loadStatus", options: .new, context: nil)
        
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if self.rasterLayer.loadStatus == AGSLoadStatus.loaded {
            self.mapView.setViewpoint(AGSViewpoint(center: (self.rasterLayer.fullExtent?.center)!, scale: 80000))
        }
    }
    
}
