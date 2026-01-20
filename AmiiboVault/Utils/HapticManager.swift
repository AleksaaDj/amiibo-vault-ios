//
//  HapticManager.swift
//  AmiiboVault
//
//  Haptic Feedback Manager for providing tactile feedback to users
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    /// Light haptic feedback - for button taps, selections
    func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Medium haptic feedback - for more significant actions
    func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// Heavy haptic feedback - for important actions
    func heavyImpact() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// Success haptic feedback - for successful actions
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Error haptic feedback - for errors
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Warning haptic feedback - for warnings
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Selection haptic feedback - for selection changes
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

