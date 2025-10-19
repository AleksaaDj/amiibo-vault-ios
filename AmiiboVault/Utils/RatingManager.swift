import Foundation
import StoreKit
import SwiftUI
import Combine

class RatingManager: ObservableObject {
    static let shared = RatingManager()
    
    private let userDefaults = UserDefaults.standard
    private let appOpenedRateTimesKey = "app_opened_rate_times"
    
    // Show rating dialog after 3 app launches (matching Android)
    private let targetAppOpenedTimes = 3
    
    private init() {}
    
    // MARK: - App Launch Tracking
    func incrementAppOpenedTimes() {
        let currentTimes = getAppOpenedRateTimes()
        setAppOpenedRateTimes(currentTimes + 1)
    }
    
    func getAppOpenedRateTimes() -> Int {
        return userDefaults.integer(forKey: appOpenedRateTimesKey)
    }
    
    private func setAppOpenedRateTimes(_ times: Int) {
        userDefaults.set(times, forKey: appOpenedRateTimesKey)
    }
    
    // MARK: - Rating Logic
    func shouldShowRatingDialog() -> Bool {
        // Show after target number of app opens
        // Let Apple handle the rate limiting internally
        return getAppOpenedRateTimes() >= targetAppOpenedTimes
    }
    
    func requestRating() {
        // Reset the counter after showing rating
        setAppOpenedRateTimes(0)
        
        // Use iOS native rating prompt (only works when app is on App Store)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
        
        // DON'T mark as clicked immediately - let Apple handle the rate limiting
        // Apple will automatically prevent showing the dialog too frequently
        // Only mark as clicked if user actually rates (which we can't detect)
    }
    
    // MARK: - Testing Methods
    func requestRatingForTesting() {
        // Reset the counter after showing rating
        setAppOpenedRateTimes(0)
        
        // For testing: Show a simple alert instead of native rating
        // This will help you test the timing and logic
        print("🎯 RATING DIALOG WOULD SHOW NOW (App opened 3 times)")
        print("📱 In production, this would show the native iOS rating dialog")
    }
    
    // MARK: - Debug Methods
    func resetRatingForTesting() {
        userDefaults.removeObject(forKey: appOpenedRateTimesKey)
        print("🔄 Rating state reset for testing")
    }
    
    func getDebugInfo() -> String {
        return """
        📊 Rating Debug Info:
        - App opened times: \(getAppOpenedRateTimes())
        - Should show rating: \(shouldShowRatingDialog())
        - Target times: \(targetAppOpenedTimes)
        """
    }
    
    // MARK: - Manual Rating (for Support screen)
    func openAppStoreRating() {
        // Open App Store directly for rating
        if let url = URL(string: "https://apps.apple.com/app/id6753917936?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}
