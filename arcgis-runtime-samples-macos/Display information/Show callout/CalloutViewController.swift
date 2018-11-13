//
// Copyright 2016 Esri.
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

import Cocoa
import ArcGIS

class CalloutViewController: NSViewController, AGSGeoViewTouchDelegate {
    
    @IBOutlet private weak var mapView: AGSMapView!
    private var map: AGSMap!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //initialize map with topographic basemap
        self.map = AGSMap(basemap: .topographic())
        
        //assign map to the map view
        self.mapView.map = self.map
        
        //register as the map view's touch delegate
        //in order to get tap notifications
        self.mapView.touchDelegate = self
        
        //zoom to custom view point
        self.mapView.setViewpointCenter(AGSPoint(x: -1.2e7, y: 5e6, spatialReference: AGSSpatialReference.webMercator()), scale: 4e7, completion: nil)
    }
    
    //method to show callout
    private func showCallout(for point: AGSPoint) {
        self.mapView.callout.title = "Location"
        self.mapView.callout.detail = String(format: "x: %.2f, y: %.2f", point.x, point.y)
        self.mapView.callout.show(at: point, screenOffset: CGPoint.zero, rotateOffsetWithMap: false, animated: false)
    }
    
    //MARK: - AGSGeoViewTouchDelegate
    
    //show callout when user does long press on map
    func geoView(_ geoView: AGSGeoView, didLongPressAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        self.showCallout(for: mapPoint)
    }
    
    //update the callout when user moves long press
    func geoView(_ geoView: AGSGeoView, didMoveLongPressToScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        self.showCallout(for: mapPoint)
    }
    
    //Dismiss the callout on long press end
    func geoView(_ geoView: AGSGeoView, didEndLongPressAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        self.mapView.callout.dismiss()
    }
    
    //Dismiss the callout if long press is cancelled
    func geoViewDidCancelLongPress(_ geoView: AGSGeoView) {
        self.mapView.callout.dismiss()
    }
}
