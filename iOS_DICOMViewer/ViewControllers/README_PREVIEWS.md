# SwiftUI Previews for UIKit View Controllers

This directory contains SwiftUI preview implementations for all major UIKit view controllers in the iOS DICOM Viewer app. These previews enable rapid UI development and testing without needing to run the full app or navigate through complex flows.

## Available Previews

### Individual View Controller Previews

1. **MainViewController+Preview.swift**
   - Main application controller with welcome interface
   - Shows service initialization and modern UI design
   - Available in light/dark modes and iPad layout

2. **StudyListViewController+Preview.swift**
   - DICOM study list with realistic mock data
   - Demonstrates both populated and empty states
   - Shows modern collection view layout with medical data

3. **ViewerViewController+Preview.swift**
   - DICOM image viewer with multiple study types
   - Supports CT, MR, X-Ray, and PET/CT mock studies
   - Demonstrates different imaging modalities

4. **AutoSegmentationViewController+Preview.swift**
   - Automatic segmentation interface
   - Shows both empty and loaded states
   - Demonstrates medical AI workflow UI

### Comprehensive Preview Collections

5. **AllViewControllers+Preview.swift**
   - Tabbed interface showing all controllers
   - Navigation-based showcase
   - Grid layout for comparison
   - Multiple device and theme variations

## Mock Data System

### MockDataProvider.swift
A centralized utility class that provides realistic DICOM mock data:

- **Study Types**: CT Chest, MR Brain, X-Ray, PET/CT, Mammography
- **Realistic Metadata**: Proper DICOM UIDs, patient data, imaging parameters
- **Multiple Series**: Multi-series studies with appropriate instance counts
- **Modality-Specific Data**: Window/level settings, pixel spacing, slice thickness

## How to Use

### In Xcode Canvas
1. Open any `*+Preview.swift` file
2. Enable Canvas (Editor → Canvas)
3. Click "Resume" to see live previews
4. Use the preview selector to switch between variants

### Preview Variants Available
- **Light/Dark Mode**: All controllers support both themes
- **Device Sizes**: iPhone, iPad, iPhone SE variations
- **Data States**: Empty states, populated states, different study types
- **Interactive**: Some previews support basic interaction

### Adding New Previews

To add a preview for a new view controller:

```swift
#if DEBUG
import SwiftUI

struct YourViewControllerPreview: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> YourViewController {
        let viewController = YourViewController()
        // Setup mock data if needed
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: YourViewController, context: Context) {
        // Handle updates if needed
    }
}

#Preview("Your Controller") {
    YourViewControllerPreview()
}
#endif
```

## Benefits

### Development Speed
- **Instant Feedback**: See UI changes immediately without app rebuild
- **Multiple States**: Test different data states simultaneously
- **Device Testing**: Preview on multiple device sizes at once

### Quality Assurance
- **Consistent Mock Data**: Standardized test data across all previews
- **Edge Cases**: Easy to test empty states, error conditions
- **Accessibility**: Preview with different accessibility settings

### Team Collaboration
- **Design Review**: Designers can see exact implementation
- **Documentation**: Visual documentation of UI states
- **Onboarding**: New developers can explore UI without setup

## Best Practices

### Mock Data
- Use `MockDataProvider.shared` for consistent test data
- Create realistic medical scenarios
- Include edge cases (empty states, errors)

### Preview Organization
- Group related previews together
- Use descriptive preview names
- Include device and theme variations

### Performance
- Keep previews lightweight
- Avoid heavy computations in preview code
- Use `#if DEBUG` to exclude from release builds

## Troubleshooting

### Common Issues

1. **Preview Not Loading**
   - Check for compilation errors
   - Ensure all dependencies are available
   - Try cleaning build folder

2. **Mock Data Not Appearing**
   - Verify `MockDataProvider` is properly imported
   - Check timing of data setup (use `DispatchQueue.main.asyncAfter` if needed)

3. **Memory Issues**
   - Avoid creating too many large mock datasets
   - Use lazy loading for complex data

### Debug Tips
- Use `print()` statements in preview code
- Check Xcode console for preview-specific errors
- Test previews on different Xcode versions

## Integration with Main App

The preview system is designed to be:
- **Isolated**: Doesn't affect production code
- **Consistent**: Uses same models and data structures
- **Maintainable**: Easy to update when UI changes

All preview code is wrapped in `#if DEBUG` to ensure it's excluded from release builds while providing powerful development tools during the development process. 