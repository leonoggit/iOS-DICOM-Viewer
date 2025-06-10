//
//  HapticFeedback.swift
//  iOS_DICOMViewer
//
//  Utility for providing haptic feedback throughout the app
//

import UIKit

enum HapticFeedback {
    private static let impactLight = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()
    
    static func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    static func windowLevelChanged() {
        selection.selectionChanged()
    }
    
    static func measurementStarted() {
        impactMedium.impactOccurred()
    }
    
    static func measurementCompleted() {
        notification.notificationOccurred(.success)
    }
    
    static func windowLevelReset() {
        impactLight.impactOccurred()
    }
}
