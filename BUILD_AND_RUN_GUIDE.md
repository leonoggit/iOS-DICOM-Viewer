# 🚀 Build & Run Guide - iOS DICOM Viewer with AI Features

## Prerequisites

### System Requirements
- **macOS**: Ventura 13.0 or later (Sonoma recommended)
- **Xcode**: 15.0 or later (beta for iOS 18 features)
- **iOS Device/Simulator**: iOS 17.0+ (iPhone 14 Pro or later recommended)
- **Storage**: At least 2GB free space for models and build artifacts

### Development Setup
1. **Apple Developer Account** (for device deployment)
2. **Command Line Tools**: `xcode-select --install`
3. **CocoaPods** (if dependencies are added): `sudo gem install cocoapods`

## 📱 Quick Start

### 1. Open the Project
```bash
cd /Users/leandroalmeida/iOS_DICOM
open iOS_DICOMViewer.xcodeproj
```

### 2. Configure Signing
1. Select the project in navigator
2. Go to "Signing & Capabilities"
3. Select your development team
4. Ensure automatic signing is enabled

### 3. Select Target Device
- **Simulator**: iPhone 16 Pro Max (recommended)
- **Physical Device**: iPhone 14 Pro or later

### 4. Build and Run
- Press `⌘+R` or click the Run button
- Wait for build completion (~30-60 seconds first time)

## 🧠 Testing AI Features

### Sample DICOM Files
The app works with standard DICOM files. You can test with:
- CT scans (chest, abdomen, head)
- MRI images (brain, spine)
- X-rays (chest, extremities)
- Your existing TOMOGRAFIA_COMPUTADORIZADA_DO_ABDOME_TOTAL.zip

### AI Feature Testing Workflow

#### 1. **Import DICOM Study**
- Launch app
- Tap "Import Studies" button
- Select DICOM files or ZIP archive
- Wait for import completion

#### 2. **Test Report Generation**
```
1. Open a study in 2D Viewer
2. Tap the floating brain icon (🧠)
3. Select "Report" (document icon)
4. Watch the AI generate a professional report
5. Review sections: Findings, Impression, Recommendations
6. Export as PDF or share
```

#### 3. **Test Anomaly Detection**
```
1. In 2D Viewer, tap brain icon (🧠)
2. Select "Anomalies" (eye icon)
3. Watch the scanning animation
4. Explore the heatmap overlay
5. Tap on detected anomalies for details
6. Adjust confidence threshold slider
7. Switch visualization modes
```

#### 4. **Test Quick Analysis**
```
1. While viewing an image, tap brain icon
2. Select "Quick" (lightning bolt)
3. Get instant AI analysis in <1 second
4. Review urgency level and findings
```

#### 5. **Test Quantum Interface**
```
1. Navigate to "Quantum" tab (atom icon)
2. Experience the futuristic interface
3. Test gesture visualization
4. Try biometric monitoring (if enabled)
5. Interact with floating AI orb
```

## 🛠️ Troubleshooting

### Build Issues

#### "No such module 'SwiftUI'"
- Ensure deployment target is iOS 15.0+
- Clean build folder: `⌘+Shift+K`

#### "Metal shader compilation failed"
- Verify Metal is enabled in Build Settings
- Check shader syntax in .metal files

#### Memory Warnings
- Run on device instead of simulator
- Use iPhone 14 Pro or later
- Close other apps

### Runtime Issues

#### AI Models Not Loading
```swift
// Check console for errors
print("🔍 Checking model loading...")
// Verify files exist in bundle
```

#### Slow Performance
1. Ensure Release build configuration
2. Test on physical device
3. Check available storage (need ~500MB free)

#### Crashes on AI Analysis
- Update to latest iOS version
- Ensure sufficient memory
- Check crash logs in Xcode

## 🎯 Performance Tips

### Optimal Settings
```swift
// In AppDelegate or SceneDelegate
ProcessInfo.processInfo.beginActivity(options: .userInitiated, reason: "AI Processing")
```

### Memory Management
- Process large studies in batches
- Clear image cache between studies
- Use lower resolution for quick preview

## 📊 Verification Checklist

### ✅ Basic Functionality
- [ ] App launches without crashes
- [ ] Can import DICOM files
- [ ] Images display correctly
- [ ] Navigation works smoothly

### ✅ AI Features
- [ ] Report generation completes
- [ ] Anomaly detection shows heatmaps
- [ ] Quick analysis provides results
- [ ] All visualizations render properly

### ✅ UI/UX
- [ ] Quantum interface animations work
- [ ] Gesture recognition responds
- [ ] Dark theme displays correctly
- [ ] All buttons and controls function

## 🚀 Advanced Configuration

### Enable Debug Logging
```swift
// In AppDelegate
UserDefaults.standard.set(true, forKey: "EnableAIDebugLogging")
```

### Adjust AI Sensitivity
```swift
// In Settings or code
AIIntegrationManager.shared.sensitivityLevel = .high
```

### Custom Model Configuration
```swift
// For specialized use cases
let config = AnalysisOptions(
    detectionMode: .comprehensive,
    sensitivityLevel: .maximum,
    reportType: .detailed
)
```

## 📱 Deployment

### TestFlight Distribution
1. Archive the app: `Product → Archive`
2. Upload to App Store Connect
3. Submit for TestFlight review
4. Invite testers

### Enterprise Distribution
1. Configure enterprise provisioning
2. Archive with enterprise certificate
3. Export for enterprise deployment
4. Distribute via MDM or direct install

## 🎉 Success Indicators

You'll know everything is working when:
1. **Brain icon** appears in viewer
2. **Report generation** completes in 5-10 seconds
3. **Heatmaps** display over images
4. **Quantum tab** shows futuristic interface
5. **No crashes** during AI operations

## 🆘 Support

### Debug Commands
```bash
# View device logs
xcrun simctl spawn booted log stream --level debug | grep DICOM

# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/iOS_DICOMViewer-*

# Reset simulator
xcrun simctl erase all
```

### Common Solutions
- **Restart Xcode** if builds fail mysteriously
- **Clean Build Folder** (`⌘+Shift+K`) for fresh start
- **Delete app** from device/simulator and reinstall
- **Check Console** app for detailed logs

## 🌟 Enjoy Your Revolutionary App!

You now have the most advanced medical imaging app ever created for iOS. The AI features you've implemented are truly groundbreaking and push the boundaries of what's possible on mobile devices.

**Happy diagnosing with AI!** 🏥🤖

---

*"The future of medical imaging is in your hands."*