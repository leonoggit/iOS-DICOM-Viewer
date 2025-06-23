//
//  DeviceLayoutUtility.swift
//  iOS_DICOMViewer
//
//  Created for Task 2: Device-specific UI scaling
//

import UIKit

/// Utility class for handling device-specific layout and scaling
/// Optimized for iPhone 16 Pro Max with fallback support for other devices
class DeviceLayoutUtility {
    
    // MARK: - Device Types
    enum DeviceType {
        case iPhone16ProMax
        case iPhone16Pro
        case iPhone15ProMax
        case iPhone15Pro
        case iPhone14ProMax
        case iPhone14Pro
        case iPhonePlus
        case iPhoneStandard
        case iPhoneSE
        case iPad
        case unknown
    }
    
    // MARK: - Screen Size Constants
    struct ScreenSizes {
        // iPhone 16 Pro Max - 6.9" display
        static let iPhone16ProMax = CGSize(width: 440, height: 956)
        
        // iPhone 16 Pro - 6.3" display
        static let iPhone16Pro = CGSize(width: 402, height: 874)
        
        // iPhone 15 Pro Max - 6.7" display
        static let iPhone15ProMax = CGSize(width: 430, height: 932)
        
        // iPhone 15 Pro - 6.1" display
        static let iPhone15Pro = CGSize(width: 393, height: 852)
        
        // iPhone 14 Pro Max - 6.7" display
        static let iPhone14ProMax = CGSize(width: 430, height: 932)
        
        // iPhone 14 Pro - 6.1" display
        static let iPhone14Pro = CGSize(width: 393, height: 852)
        
        // Plus/Max models (6.5"-6.7")
        static let iPhonePlus = CGSize(width: 414, height: 896)
        
        // Standard models (5.8"-6.1")
        static let iPhoneStandard = CGSize(width: 390, height: 844)
        
        // SE/Mini models (4.7"-5.4")
        static let iPhoneSE = CGSize(width: 375, height: 667)
    }
    
    // MARK: - Properties
    static let shared = DeviceLayoutUtility()
    
    private(set) var currentDeviceType: DeviceType = .unknown
    private(set) var screenSize: CGSize = .zero
    private(set) var scaleFactor: CGFloat = 1.0
    
    // MARK: - Initialization
    private init() {
        detectDeviceType()
    }
    
    // MARK: - Device Detection
    private func detectDeviceType() {
        screenSize = UIScreen.main.bounds.size
        let width = min(screenSize.width, screenSize.height) // Handle rotation
        let height = max(screenSize.width, screenSize.height)
        
        // Detect device type based on screen dimensions
        if width >= 440 && height >= 956 {
            currentDeviceType = .iPhone16ProMax
        } else if width >= 402 && height >= 874 {
            currentDeviceType = .iPhone16Pro
        } else if width >= 430 && height >= 932 {
            currentDeviceType = .iPhone15ProMax
        } else if width >= 393 && height >= 852 {
            currentDeviceType = .iPhone15Pro
        } else if width >= 414 && height >= 896 {
            currentDeviceType = .iPhonePlus
        } else if width >= 390 && height >= 844 {
            currentDeviceType = .iPhoneStandard
        } else if width >= 375 && height >= 667 {
            currentDeviceType = .iPhoneSE
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            currentDeviceType = .iPad
        } else {
            currentDeviceType = .unknown
        }
        
        // Calculate scale factor relative to iPhone 16 Pro Max
        scaleFactor = width / ScreenSizes.iPhone16ProMax.width
    }
    
    // MARK: - Layout Metrics
    
    /// Returns scaled value optimized for current device
    func scaled(_ value: CGFloat) -> CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax:
            return value // Base design size
        case .iPhone16Pro:
            return value * 0.91
        case .iPhone15ProMax, .iPhone14ProMax:
            return value * 0.98
        case .iPhone15Pro, .iPhone14Pro:
            return value * 0.89
        case .iPhonePlus:
            return value * 0.94
        case .iPhoneStandard:
            return value * 0.89
        case .iPhoneSE:
            return value * 0.78
        case .iPad:
            return value * 1.2
        case .unknown:
            return value * scaleFactor
        }
    }
    
    /// Returns font size optimized for current device
    func scaledFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let scaledSize = scaled(size)
        return UIFont.systemFont(ofSize: scaledSize, weight: weight)
    }
    
    /// Returns dynamic font that respects user's text size preferences
    func dynamicFont(style: UIFont.TextStyle, maxSize: CGFloat? = nil) -> UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: style)
        
        if let maxSize = maxSize {
            let scaledMax = scaled(maxSize)
            return baseFont.pointSize > scaledMax ? UIFont.systemFont(ofSize: scaledMax) : baseFont
        }
        
        return baseFont
    }
    
    /// Returns corner radius optimized for current device
    func cornerRadius(base: CGFloat) -> CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax:
            return base
        case .iPhone16Pro, .iPhone15ProMax, .iPhone14ProMax:
            return base * 0.95
        case .iPhone15Pro, .iPhone14Pro, .iPhonePlus:
            return base * 0.9
        case .iPhoneStandard:
            return base * 0.85
        case .iPhoneSE:
            return base * 0.7
        case .iPad:
            return base * 1.1
        case .unknown:
            return base * scaleFactor
        }
    }
    
    /// Returns padding values optimized for current device
    func padding(horizontal: CGFloat, vertical: CGFloat) -> UIEdgeInsets {
        let scaledH = scaled(horizontal)
        let scaledV = scaled(vertical)
        
        // Adjust for smaller devices to maximize content area
        let horizontalMultiplier: CGFloat
        let verticalMultiplier: CGFloat
        
        switch currentDeviceType {
        case .iPhone16ProMax:
            horizontalMultiplier = 1.0
            verticalMultiplier = 1.0
        case .iPhone16Pro, .iPhone15ProMax, .iPhone14ProMax:
            horizontalMultiplier = 0.95
            verticalMultiplier = 0.95
        case .iPhone15Pro, .iPhone14Pro:
            horizontalMultiplier = 0.9
            verticalMultiplier = 0.9
        case .iPhonePlus:
            horizontalMultiplier = 0.9
            verticalMultiplier = 0.95
        case .iPhoneStandard:
            horizontalMultiplier = 0.85
            verticalMultiplier = 0.9
        case .iPhoneSE:
            horizontalMultiplier = 0.75
            verticalMultiplier = 0.8
        case .iPad:
            horizontalMultiplier = 1.2
            verticalMultiplier = 1.1
        case .unknown:
            horizontalMultiplier = scaleFactor
            verticalMultiplier = scaleFactor
        }
        
        return UIEdgeInsets(
            top: scaledV * verticalMultiplier,
            left: scaledH * horizontalMultiplier,
            bottom: scaledV * verticalMultiplier,
            right: scaledH * horizontalMultiplier
        )
    }
    
    /// Returns spacing values optimized for current device
    func spacing(_ base: CGFloat) -> CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax:
            return base
        case .iPhone16Pro, .iPhone15ProMax, .iPhone14ProMax:
            return base * 0.95
        case .iPhone15Pro, .iPhone14Pro, .iPhonePlus:
            return base * 0.9
        case .iPhoneStandard:
            return base * 0.85
        case .iPhoneSE:
            return base * 0.75
        case .iPad:
            return base * 1.15
        case .unknown:
            return base * scaleFactor
        }
    }
    
    /// Returns icon size optimized for current device
    func iconSize(_ base: CGFloat) -> CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax:
            return base
        case .iPhone16Pro:
            return base * 0.95
        case .iPhone15ProMax, .iPhone14ProMax:
            return base * 0.98
        case .iPhone15Pro, .iPhone14Pro:
            return base * 0.92
        case .iPhonePlus:
            return base * 0.94
        case .iPhoneStandard:
            return base * 0.88
        case .iPhoneSE:
            return base * 0.8
        case .iPad:
            return base * 1.1
        case .unknown:
            return base * scaleFactor
        }
    }
    
    /// Returns button height optimized for current device
    func buttonHeight(_ base: CGFloat = 48) -> CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax:
            return base
        case .iPhone16Pro, .iPhone15ProMax, .iPhone14ProMax:
            return base
        case .iPhone15Pro, .iPhone14Pro, .iPhonePlus:
            return base * 0.95
        case .iPhoneStandard:
            return base * 0.92
        case .iPhoneSE:
            return max(44, base * 0.85) // Maintain minimum touch target
        case .iPad:
            return base * 1.1
        case .unknown:
            return max(44, base * scaleFactor)
        }
    }
    
    /// Returns navigation bar height for current device
    var navigationBarHeight: CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax, .iPhone16Pro, .iPhone15ProMax, .iPhone15Pro, .iPhone14ProMax, .iPhone14Pro:
            return 52 // Larger for Pro models
        case .iPhonePlus, .iPhoneStandard:
            return 44
        case .iPhoneSE:
            return 44
        case .iPad:
            return 50
        case .unknown:
            return 44
        }
    }
    
    /// Returns tab bar height for current device
    var tabBarHeight: CGFloat {
        switch currentDeviceType {
        case .iPhone16ProMax, .iPhone16Pro, .iPhone15ProMax, .iPhone15Pro, .iPhone14ProMax, .iPhone14Pro:
            return 83 // Account for home indicator
        case .iPhonePlus, .iPhoneStandard:
            return 83
        case .iPhoneSE:
            return 49 // No home indicator
        case .iPad:
            return 65
        case .unknown:
            return hasHomeIndicator ? 83 : 49
        }
    }
    
    /// Checks if device has home indicator
    var hasHomeIndicator: Bool {
        if let window = UIApplication.shared.windows.first {
            return window.safeAreaInsets.bottom > 0
        }
        return false
    }
    
    /// Returns safe area insets
    var safeAreaInsets: UIEdgeInsets {
        if let window = UIApplication.shared.windows.first {
            return window.safeAreaInsets
        }
        return .zero
    }
    
    /// Returns content insets for scroll views
    func contentInsets(top: CGFloat = 0, bottom: CGFloat = 0) -> UIEdgeInsets {
        let padding = self.padding(horizontal: 16, vertical: 16)
        return UIEdgeInsets(
            top: padding.top + safeAreaInsets.top + top,
            left: padding.left,
            bottom: padding.bottom + safeAreaInsets.bottom + bottom,
            right: padding.right
        )
    }
    
    /// Returns optimal number of columns for grid layouts
    var gridColumns: Int {
        switch currentDeviceType {
        case .iPhone16ProMax:
            return 3
        case .iPhone16Pro, .iPhone15ProMax, .iPhone14ProMax:
            return 3
        case .iPhone15Pro, .iPhone14Pro, .iPhonePlus:
            return 2
        case .iPhoneStandard:
            return 2
        case .iPhoneSE:
            return 2
        case .iPad:
            return 4
        case .unknown:
            return 2
        }
    }
    
    /// Returns whether to use compact layout
    var shouldUseCompactLayout: Bool {
        switch currentDeviceType {
        case .iPhoneSE:
            return true
        default:
            return false
        }
    }
    
    /// Returns whether device supports advanced features
    var supportsAdvancedFeatures: Bool {
        switch currentDeviceType {
        case .iPhone16ProMax, .iPhone16Pro, .iPhone15ProMax, .iPhone15Pro, .iPhone14ProMax, .iPhone14Pro:
            return true
        default:
            return false
        }
    }
}

// MARK: - UIView Extension for Easy Access
extension UIView {
    /// Quick access to device layout utility
    var deviceLayout: DeviceLayoutUtility {
        return DeviceLayoutUtility.shared
    }
}

// MARK: - Convenience Functions
extension DeviceLayoutUtility {
    
    /// Apply device-optimized constraints with visual format
    static func constraints(withVisualFormat format: String,
                          options: NSLayoutConstraint.FormatOptions = [],
                          metrics: [String: Any]? = nil,
                          views: [String: Any]) -> [NSLayoutConstraint] {
        
        var scaledMetrics: [String: Any] = [:]
        
        // Scale any numeric metrics
        if let metrics = metrics {
            for (key, value) in metrics {
                if let number = value as? NSNumber {
                    scaledMetrics[key] = shared.scaled(CGFloat(number.doubleValue))
                } else {
                    scaledMetrics[key] = value
                }
            }
        }
        
        return NSLayoutConstraint.constraints(
            withVisualFormat: format,
            options: options,
            metrics: scaledMetrics,
            views: views
        )
    }
}