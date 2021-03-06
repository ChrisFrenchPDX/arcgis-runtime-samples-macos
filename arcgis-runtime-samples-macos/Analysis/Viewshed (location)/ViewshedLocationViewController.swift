//
// Copyright 2018 Esri.
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

class ViewshedLocationViewController: NSViewController, AGSGeoViewTouchDelegate {
    @IBOutlet weak var sceneView: AGSSceneView!
    
    @IBOutlet weak var instructionLabel: NSTextField!
    
    @IBOutlet weak var viewshedSettingsView: NSVisualEffectView!
    @IBOutlet weak var viewshedSettingsTextField: NSTextField!

    @IBOutlet weak var obstructedAreaColorWell: NSColorWell!
    @IBOutlet weak var visibleAreaColorWell: NSColorWell!
    @IBOutlet weak var frustrumOutlineColorWell: NSColorWell!

    @IBOutlet weak var frustumOutlineSegmentedControl: NSSegmentedControl!
    @IBOutlet weak var headingSlider: NSSlider!
    @IBOutlet weak var headingLabel: NSTextField!
    @IBOutlet weak var pitchSlider: NSSlider!
    @IBOutlet weak var pitchLabel: NSTextField!
    @IBOutlet weak var horizontalAngleSlider: NSSlider!
    @IBOutlet weak var horizontalAngleLabel: NSTextField!
    @IBOutlet weak var verticalAngleSlider: NSSlider!
    @IBOutlet weak var verticalAngleLabel: NSTextField!
    @IBOutlet weak var minDistanceSlider: NSSlider!
    @IBOutlet weak var minDistanceLabel: NSTextField!
    @IBOutlet weak var maxDistanceSlider: NSSlider!
    @IBOutlet weak var maxDistanceLabel: NSTextField!

    private var viewshed: AGSLocationViewshed!
    private var analysisOverlay: AGSAnalysisOverlay!
    
    private var canMoveViewshed: Bool = false {
        didSet {
            guard canMoveViewshed != oldValue else { return }
            updateInstructionLabel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateInstructionLabel()
        
        // settings
        frustumOutlineSegmentedControl.setSelected(false, forSegment: 0)
        frustumOutlineSegmentedControl.setSelected(true, forSegment: 1)
        
        // initialize the scene with an imagery basemap
        let scene = AGSScene(basemap: .imagery())
        
        // assign the scene to the scene view
        sceneView.scene = scene
        
        // initialize the camera and set the viewpoint specified by the camera position
        let camera = AGSCamera(lookAt: AGSPoint(x: -4.50, y: 48.4, z: 100.0, spatialReference: .wgs84()), distance: 200, heading: 20, pitch: 70, roll: 0)
        sceneView.setViewpointCamera(camera)
        
        /// The url of the image service for elevation in Brest, France.
        let brestElevationServiceURL = URL(string: "https://scene.arcgis.com/arcgis/rest/services/BREST_DTM_1M/ImageServer")!
        // initialize the elevation source with the service URL and add it to the base surface of the scene
        let elevationSrc = AGSArcGISTiledElevationSource(url: brestElevationServiceURL)
        scene.baseSurface?.elevationSources.append(elevationSrc)
        
        /// The url of the scene service for buildings in Brest, France.
        let brestBuildingsServiceURL = URL(string: "https://tiles.arcgis.com/tiles/P3ePLMYs2RVChkJx/arcgis/rest/services/Buildings_Brest/SceneServer/layers/0")!
        // initialize the scene layer with the scene layer URL and add it to the scene
        let buildings = AGSArcGISSceneLayer(url: brestBuildingsServiceURL)
        scene.operationalLayers.add(buildings)
        
        // initialize a viewshed analysis object with arbitrary location (the location will be defined by the user), heading, pitch, view angles, and distance range (in meters) from which visibility is calculated from the observer location
        viewshed = AGSLocationViewshed(location: AGSPoint(x: 0.0, y: 0.0, z: 0.0, spatialReference: .wgs84()), heading: 20, pitch: 70, horizontalAngle: 45, verticalAngle: 90, minDistance: 50, maxDistance: 1000)
        
        // create an analysis overlay for the viewshed and to add it to the scene view
        analysisOverlay = AGSAnalysisOverlay()
        analysisOverlay.analyses.add(viewshed)
        sceneView.analysisOverlays.add(analysisOverlay)
        
        // set touch delegate on scene view as self
        sceneView.touchDelegate = self
    }

    override func viewWillAppear() {
        //
        // Set style of settings view
        viewshedSettingsView.wantsLayer = true
        viewshedSettingsView.layer?.cornerRadius = 10
        viewshedSettingsTextField.backgroundColor = .primaryBlue
        viewshedSettingsTextField.wantsLayer = true
        viewshedSettingsTextField.layer?.cornerRadius = 5

        obstructedAreaColorWell.color = AGSViewshed.obstructedColor().withAlphaComponent(1)
        visibleAreaColorWell.color = AGSViewshed.visibleColor().withAlphaComponent(1)
        frustrumOutlineColorWell.color = AGSViewshed.frustumOutlineColor().withAlphaComponent(1)
    }
    
    func updateInstructionLabel() {
        let instruction: String
        if canMoveViewshed {
            instruction = "Click-and-drag to move the viewshed"
        } else {
            instruction = "Click on the map to add observer location"
        }
        instructionLabel.stringValue = instruction
    }
    
    // MARK: - AGSGeoViewTouchDelegate
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        canMoveViewshed = true
        // update the observer location from which the viewshed is calculated
        viewshed.location = mapPoint
    }
    
    func geoView(_ geoView: AGSGeoView, didTouchDownAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint, completion: @escaping (Bool) -> Void) {
        // tell the ArcGIS Runtime if we are going to handle interaction
        canMoveViewshed ? completion(true) : completion(false)
    }
    
    func geoView(_ geoView: AGSGeoView, didTouchDragToScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        // update the observer location from which the viewshed is calculated
        viewshed.location = mapPoint
    }
    
    // MARK: - Actions
    
    @IBAction func analysisOverlayVisibilityAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
             analysisOverlay.isVisible = true
        case 1:
             analysisOverlay.isVisible = false
        default:
            break
        }
    }
    
    @IBAction func frustumOutlineVisibilityAction(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            viewshed.isFrustumOutlineVisible = true
        case 1:
            viewshed.isFrustumOutlineVisible = false
        default:
            break
        }
    }
    
    @IBAction func obstructedAreaColorAction(_ sender: NSColorWell) {
         // sets the color with which non-visible areas of all viewsheds will be rendered (default: red color). This setting is applied to all viewshed analyses in the view.
        AGSViewshed.setObstructedColor(sender.color.withAlphaComponent(0.5))
    }
    
    @IBAction func visibleAreaColorAction(_ sender: NSColorWell) {
        // sets the color with which visible areas of all viewsheds will be rendered (default: green color). This setting is applied to all viewshed analyses in the view.
        AGSViewshed.setVisibleColor(sender.color.withAlphaComponent(0.5))
    }
    
    @IBAction func frustumOutlineColorAction(_ sender: NSColorWell) {
        // sets the color used to render the frustum outline (default: blue color). This setting is applied to all viewshed analyses in the view.
        AGSViewshed.setFrustumOutlineColor(sender.color)
    }
    
    @IBAction private func sliderValueChanged(_ sender: NSSlider) {
        if sender == headingSlider {
            headingLabel.stringValue = "\(sender.integerValue)"
            viewshed.heading = sender.doubleValue
        } else if sender == pitchSlider {
            pitchLabel.stringValue = "\(sender.integerValue)"
            viewshed.pitch = sender.doubleValue
        } else if sender == horizontalAngleSlider {
            horizontalAngleLabel.stringValue = "\(sender.integerValue)"
            viewshed.horizontalAngle = sender.doubleValue
        } else if sender == verticalAngleSlider {
            verticalAngleLabel.stringValue = "\(sender.integerValue)"
            viewshed.verticalAngle = sender.doubleValue
        } else if sender == minDistanceSlider {
            minDistanceLabel.stringValue = "\(sender.integerValue)"
            viewshed.minDistance = sender.doubleValue
        } else if sender == maxDistanceSlider {
            maxDistanceLabel.stringValue = "\(sender.integerValue)"
            viewshed.maxDistance = sender.doubleValue
        }
    }
}
