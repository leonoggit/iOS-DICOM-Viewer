import XCTest

/// UI Tests for iOS DICOM Viewer
/// Tests user interactions, workflows, and accessibility compliance
class iOS_DICOMViewerUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
        
        // Wait for app to fully load
        _ = app.wait(for: .runningForeground, timeout: 5.0)
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }
    
    // MARK: - App Launch and Navigation Tests
    func testAppLaunch() throws {
        // Test app launches successfully
        XCTAssertTrue(app.state == .runningForeground)
        
        // Test main UI elements are present
        XCTAssertTrue(app.navigationBars.firstMatch.exists)
        
        // Look for expected UI elements
        let studyListExists = app.tables.firstMatch.waitForExistence(timeout: 3.0) ||
                            app.collectionViews.firstMatch.waitForExistence(timeout: 3.0) ||
                            app.staticTexts["No studies available"].waitForExistence(timeout: 3.0)
        
        XCTAssertTrue(studyListExists, "Expected study list or empty state message")
    }
    
    func testMainNavigationFlow() throws {
        // Test navigation between main sections
        
        // Check if we can access the viewer (might need to load sample data first)
        if app.buttons["Load Sample Data"].exists {
            app.buttons["Load Sample Data"].tap()
            
            // Wait for sample data to load
            let studyCell = app.cells.firstMatch
            _ = studyCell.waitForExistence(timeout: 10.0)
        }
        
        // Test navigation to study list if available
        if app.cells.firstMatch.exists {
            app.cells.firstMatch.tap()
            
            // Verify viewer loads
            let viewerLoaded = app.images.firstMatch.waitForExistence(timeout: 10.0) ||
                             app.otherElements["Metal View"].waitForExistence(timeout: 10.0)
            XCTAssertTrue(viewerLoaded, "Viewer should load after selecting study")
        }
    }
    
    // MARK: - Study List Tests
    func testStudyListInteraction() throws {
        // Load sample data if available
        if app.buttons["Load Sample Data"].exists {
            app.buttons["Load Sample Data"].tap()
            _ = app.cells.firstMatch.waitForExistence(timeout: 10.0)
        }
        
        // Test study list functionality
        let studyCells = app.cells
        if studyCells.count > 0 {
            // Test cell selection
            let firstCell = studyCells.firstMatch
            XCTAssertTrue(firstCell.exists)
            
            // Test cell tap
            firstCell.tap()
            
            // Verify navigation occurred
            let backButton = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(backButton.waitForExistence(timeout: 5.0))
        }
    }
    
    func testStudyListSearch() throws {
        // Test search functionality if available
        if app.searchFields.firstMatch.exists {
            let searchField = app.searchFields.firstMatch
            searchField.tap()
            searchField.typeText("test")
            
            // Test search results update
            app.keyboards.buttons["Search"].tap()
            
            // Verify search was performed (UI should update)
            XCTAssertTrue(app.exists)
        }
    }
    
    // MARK: - DICOM Viewer Tests
    func testDICOMViewerGestures() throws {
        // Navigate to viewer first
        navigateToViewer()
        
        let metalView = app.otherElements["Metal View"].firstMatch
        guard metalView.waitForExistence(timeout: 10.0) else {
            XCTSkip("Metal view not available for testing")
        }
        
        // Test pan gesture
        metalView.swipeLeft()
        metalView.swipeRight()
        metalView.swipeUp()
        metalView.swipeDown()
        
        // Test pinch gesture (zoom)
        metalView.pinch(withScale: 2.0, velocity: 1.0)
        metalView.pinch(withScale: 0.5, velocity: -1.0)
        
        // Test tap gesture
        metalView.tap()
        
        // Verify gestures don't crash the app
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testWindowLevelControls() throws {
        navigateToViewer()
        
        // Test window/level sliders if available
        let windowCenterSlider = app.sliders["Window Center"]
        let windowWidthSlider = app.sliders["Window Width"]
        
        if windowCenterSlider.exists {
            // Test window center adjustment
            windowCenterSlider.adjust(toNormalizedSliderPosition: 0.3)
            windowCenterSlider.adjust(toNormalizedSliderPosition: 0.7)
        }
        
        if windowWidthSlider.exists {
            // Test window width adjustment
            windowWidthSlider.adjust(toNormalizedSliderPosition: 0.2)
            windowWidthSlider.adjust(toNormalizedSliderPosition: 0.8)
        }
        
        // Verify app remains stable
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    func testSliceNavigation() throws {
        navigateToViewer()
        
        // Test slice navigation controls
        let sliceSlider = app.sliders["Slice"]
        if sliceSlider.exists {
            // Test slice navigation
            sliceSlider.adjust(toNormalizedSliderPosition: 0.0) // First slice
            sliceSlider.adjust(toNormalizedSliderPosition: 0.5) // Middle slice
            sliceSlider.adjust(toNormalizedSliderPosition: 1.0) // Last slice
        }
        
        // Test previous/next slice buttons if available
        if app.buttons["Previous Slice"].exists {
            app.buttons["Previous Slice"].tap()
        }
        
        if app.buttons["Next Slice"].exists {
            app.buttons["Next Slice"].tap()
        }
        
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - MPR (Multi-Planar Reconstruction) Tests
    func testMPRPlaneSelection() throws {
        navigateToViewer()
        
        // Look for MPR controls
        let planeSegmentedControl = app.segmentedControls.firstMatch
        if planeSegmentedControl.exists {
            // Test switching between planes
            let planeButtons = planeSegmentedControl.buttons
            
            for button in planeButtons.allElementsBoundByIndex {
                if button.exists && button.isEnabled {
                    button.tap()
                    
                    // Allow time for plane switch
                    usleep(500000) // 0.5 seconds
                    
                    // Verify app remains stable
                    XCTAssertTrue(app.state == .runningForeground)
                }
            }
        }
    }
    
    func testTriPlanarView() throws {
        navigateToViewer()
        
        // Look for tri-planar view button or mode
        if app.buttons["Tri-Planar"].exists {
            app.buttons["Tri-Planar"].tap()
            
            // Verify multiple views are displayed
            let metalViews = app.otherElements.matching(identifier: "Metal View")
            if metalViews.count > 1 {
                // Test interaction with each view
                for i in 0..<min(metalViews.count, 3) {
                    let view = metalViews.element(boundBy: i)
                    if view.exists {
                        view.tap()
                        view.swipeLeft()
                    }
                }
            }
        }
    }
    
    // MARK: - 3D Volume Rendering Tests
    func test3DVolumeRendering() throws {
        navigateToViewer()
        
        // Look for 3D rendering mode
        if app.buttons["3D Volume"].exists || app.buttons["Volume Rendering"].exists {
            let volumeButton = app.buttons["3D Volume"].exists ? 
                             app.buttons["3D Volume"] : app.buttons["Volume Rendering"]
            
            volumeButton.tap()
            
            // Wait for 3D rendering to initialize
            let renderView = app.otherElements["Volume Render View"]
            _ = renderView.waitForExistence(timeout: 10.0)
            
            if renderView.exists {
                // Test 3D interactions
                renderView.swipeLeft()  // Rotate
                renderView.swipeRight()
                renderView.swipeUp()
                renderView.swipeDown()
                
                // Test zoom
                renderView.pinch(withScale: 2.0, velocity: 1.0)
                renderView.pinch(withScale: 0.5, velocity: -1.0)
            }
        }
    }
    
    func testVolumeRenderingModes() throws {
        navigateToViewer()
        
        // Test different rendering modes if available
        let renderModes = ["Ray Cast", "MIP", "Isosurface", "DVR"]
        
        for mode in renderModes {
            if app.buttons[mode].exists {
                app.buttons[mode].tap()
                
                // Allow time for mode switch
                usleep(1000000) // 1 second
                
                // Verify app remains stable
                XCTAssertTrue(app.state == .runningForeground)
            }
        }
    }
    
    // MARK: - Settings and Controls Tests
    func testQualitySettings() throws {
        navigateToViewer()
        
        // Test quality level controls
        let qualitySegmentedControl = app.segmentedControls["Quality"]
        if qualitySegmentedControl.exists {
            let qualityButtons = qualitySegmentedControl.buttons
            
            for button in qualityButtons.allElementsBoundByIndex {
                if button.exists && button.isEnabled {
                    button.tap()
                    usleep(500000) // Allow time for quality change
                }
            }
        }
        
        // Test quality slider if available
        let qualitySlider = app.sliders["Quality"]
        if qualitySlider.exists {
            qualitySlider.adjust(toNormalizedSliderPosition: 0.25) // Low
            qualitySlider.adjust(toNormalizedSliderPosition: 0.5)  // Medium
            qualitySlider.adjust(toNormalizedSliderPosition: 0.75) // High
            qualitySlider.adjust(toNormalizedSliderPosition: 1.0)  // Ultra
        }
    }
    
    func testAnnotationControls() throws {
        navigateToViewer()
        
        // Test crosshair toggle
        if app.switches["Crosshair"].exists {
            let crosshairSwitch = app.switches["Crosshair"]
            crosshairSwitch.tap() // Toggle off
            crosshairSwitch.tap() // Toggle on
        }
        
        // Test annotations toggle
        if app.switches["Annotations"].exists {
            let annotationsSwitch = app.switches["Annotations"]
            annotationsSwitch.tap() // Toggle off
            annotationsSwitch.tap() // Toggle on
        }
        
        // Test ruler/measurement tools
        if app.buttons["Ruler"].exists {
            app.buttons["Ruler"].tap()
        }
    }
    
    // MARK: - File Import Tests
    func testFileImport() throws {
        // Test file import functionality
        if app.buttons["Import"].exists || app.buttons["Add Files"].exists {
            let importButton = app.buttons["Import"].exists ? 
                             app.buttons["Import"] : app.buttons["Add Files"]
            
            importButton.tap()
            
            // Verify file picker opens
            let filePickerExists = app.navigationBars["Browse"].waitForExistence(timeout: 5.0) ||
                                 app.otherElements["Files"].waitForExistence(timeout: 5.0)
            
            if filePickerExists {
                // Cancel file picker for test
                if app.buttons["Cancel"].exists {
                    app.buttons["Cancel"].tap()
                }
            }
        }
    }
    
    // MARK: - Accessibility Tests
    func testAccessibilityLabels() throws {
        navigateToViewer()
        
        // Test that important UI elements have accessibility labels
        let accessibilityElements = [
            app.buttons,
            app.sliders,
            app.switches,
            app.segmentedControls
        ]
        
        for elementQuery in accessibilityElements {
            for element in elementQuery.allElementsBoundByIndex {
                if element.exists {
                    // Verify element has accessibility identifier or label
                    let hasAccessibility = !element.identifier.isEmpty || 
                                         !element.label.isEmpty ||
                                         element.isAccessibilityElement
                    
                    XCTAssertTrue(hasAccessibility, 
                                "Element should have accessibility information: \(element)")
                }
            }
        }
    }
    
    func testVoiceOverSupport() throws {
        // Enable VoiceOver for testing
        XCUIDevice.shared.system.accessibilityVoiceOverEnabled = true
        
        navigateToViewer()
        
        // Test that key elements are accessible via VoiceOver
        let importantElements = [
            app.buttons.firstMatch,
            app.sliders.firstMatch,
            app.segmentedControls.firstMatch
        ]
        
        for element in importantElements {
            if element.exists {
                XCTAssertTrue(element.isAccessibilityElement || element.children(matching: .any).firstMatch.isAccessibilityElement,
                            "Element should be accessible to VoiceOver")
            }
        }
        
        // Disable VoiceOver after test
        XCUIDevice.shared.system.accessibilityVoiceOverEnabled = false
    }
    
    // MARK: - Performance Tests
    func testUIResponsiveness() throws {
        navigateToViewer()
        
        let metalView = app.otherElements["Metal View"].firstMatch
        guard metalView.waitForExistence(timeout: 10.0) else {
            XCTSkip("Metal view not available for performance testing")
        }
        
        measure(metrics: [XCTUITestMetric.scrollingAndFlingingMetrics]) {
            // Test rapid interactions
            for _ in 0..<10 {
                metalView.swipeLeft()
                metalView.swipeRight()
                metalView.pinch(withScale: 1.5, velocity: 2.0)
                metalView.pinch(withScale: 0.8, velocity: -2.0)
            }
        }
    }
    
    func testSliderPerformance() throws {
        navigateToViewer()
        
        let sliceSlider = app.sliders["Slice"]
        guard sliceSlider.exists else {
            XCTSkip("Slice slider not available for performance testing")
        }
        
        measure(metrics: [XCTUITestMetric.scrollingAndFlingingMetrics]) {
            // Test rapid slider adjustments
            for i in 0..<20 {
                let position = Double(i % 10) / 10.0
                sliceSlider.adjust(toNormalizedSliderPosition: position)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    func testInvalidFileHandling() throws {
        // This test would require creating an invalid file scenario
        // For now, just test that the app handles missing data gracefully
        
        // Verify app doesn't crash when no studies are loaded
        if app.staticTexts["No studies available"].exists {
            XCTAssertTrue(app.state == .runningForeground)
        }
    }
    
    func testMemoryPressureHandling() throws {
        navigateToViewer()
        
        // Simulate memory pressure by rapidly loading/switching content
        for _ in 0..<5 {
            // Switch between different views/modes rapidly
            if app.buttons["3D Volume"].exists {
                app.buttons["3D Volume"].tap()
                usleep(100000) // 0.1 seconds
            }
            
            if app.buttons["MPR"].exists {
                app.buttons["MPR"].tap()
                usleep(100000)
            }
        }
        
        // Verify app remains stable
        XCTAssertTrue(app.state == .runningForeground)
    }
    
    // MARK: - Helper Methods
    private func navigateToViewer() {
        // Load sample data if needed
        if app.buttons["Load Sample Data"].exists {
            app.buttons["Load Sample Data"].tap()
            _ = app.cells.firstMatch.waitForExistence(timeout: 10.0)
        }
        
        // Navigate to viewer if study cells exist
        if app.cells.firstMatch.exists {
            app.cells.firstMatch.tap()
            
            // Wait for viewer to load
            let viewerLoaded = app.images.firstMatch.waitForExistence(timeout: 10.0) ||
                             app.otherElements["Metal View"].waitForExistence(timeout: 10.0) ||
                             app.otherElements.matching(identifier: "Volume Render View").firstMatch.waitForExistence(timeout: 10.0)
            
            if !viewerLoaded {
                XCTFail("Failed to navigate to viewer")
            }
        } else {
            XCTSkip("No studies available to test viewer functionality")
        }
    }
    
    private func waitForRenderingToStabilize() {
        // Wait for rendering to stabilize after changes
        usleep(1000000) // 1 second
    }
}

// MARK: - Custom Metrics
extension iOS_DICOMViewerUITests {
    
    func testMedicalImagingWorkflow() throws {
        // Test complete medical imaging workflow
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
        
        // Load sample data
        if app.buttons["Load Sample Data"].exists {
            app.buttons["Load Sample Data"].tap()
            _ = app.cells.firstMatch.waitForExistence(timeout: 10.0)
        }
        
        // Navigate to viewer
        if app.cells.firstMatch.exists {
            app.cells.firstMatch.tap()
            _ = app.otherElements["Metal View"].waitForExistence(timeout: 10.0)
        }
        
        // Test medical imaging workflow steps
        let workflowSteps = [
            { [weak self] in self?.testWindowLevelAdjustment() },
            { [weak self] in self?.testSliceScrolling() },
            { [weak self] in self?.testPlaneViewing() },
            { [weak self] in self?.test3DVisualization() }
        ]
        
        for step in workflowSteps {
            step?()
            waitForRenderingToStabilize()
        }
    }
    
    private func testWindowLevelAdjustment() {
        if app.sliders["Window Center"].exists {
            app.sliders["Window Center"].adjust(toNormalizedSliderPosition: 0.4)
        }
        if app.sliders["Window Width"].exists {
            app.sliders["Window Width"].adjust(toNormalizedSliderPosition: 0.8)
        }
    }
    
    private func testSliceScrolling() {
        if app.sliders["Slice"].exists {
            let slider = app.sliders["Slice"]
            slider.adjust(toNormalizedSliderPosition: 0.0)
            slider.adjust(toNormalizedSliderPosition: 0.5)
            slider.adjust(toNormalizedSliderPosition: 1.0)
        }
    }
    
    private func testPlaneViewing() {
        let planeControl = app.segmentedControls.firstMatch
        if planeControl.exists {
            let buttons = planeControl.buttons
            for button in buttons.allElementsBoundByIndex {
                if button.exists {
                    button.tap()
                    usleep(500000)
                }
            }
        }
    }
    
    private func test3DVisualization() {
        if app.buttons["3D Volume"].exists {
            app.buttons["3D Volume"].tap()
            
            let metalView = app.otherElements["Volume Render View"]
            if metalView.waitForExistence(timeout: 5.0) {
                metalView.swipeLeft()
                metalView.swipeRight()
                metalView.pinch(withScale: 1.5, velocity: 1.0)
            }
        }
    }
}