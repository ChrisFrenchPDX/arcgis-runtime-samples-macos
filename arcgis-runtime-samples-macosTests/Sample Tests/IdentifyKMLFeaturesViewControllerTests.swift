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

import XCTest
import ArcGIS
@testable import ArcGIS_Runtime_SDK_Samples

class IdentifyKMLFeaturesViewControllerTests: XCTestCase {
    func makeViewController() -> IdentifyKMLFeaturesViewController {
        return NSStoryboard(name: "IdentifyKMLFeatures", bundle: nil).instantiateInitialController() as! IdentifyKMLFeaturesViewController
    }
    
    func testLoadingView() {
        let viewController = makeViewController()
        
        // Load the view.
        _ = viewController.view
        
        if let mapView = viewController.mapView {
            XCTAssertNotNil(mapView.map)
            XCTAssertEqual(mapView.map?.basemap.name, AGSBasemap.darkGrayCanvasVector().name)
            XCTAssertTrue(mapView.touchDelegate === viewController)
        } else {
            XCTFail("mapView is nil")
        }
    }
}
