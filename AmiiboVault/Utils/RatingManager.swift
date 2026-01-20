import Foundation
import StoreKit
import SwiftUI
import Combine
import UIKit

class RatingManager: NSObject, ObservableObject, SKStoreProductViewControllerDelegate {
    static let shared = RatingManager()
    
    private let userDefaults = UserDefaults.standard
    private let appOpenedRateTimesKey = "app_opened_rate_times"
    private let appOpenedAdsTimesKey = "app_opened_ads_times"
    private let adsDialogDismissedKey = "ads_dialog_dismissed"
    
    // Show rating dialog after 3 app launches (matching Android)
    private let targetAppOpenedTimes = 3
    // Show "Tired of ads" dialog after 4 app launches
    private let targetAdsDialogTimes = 4
    
    private override init() {
        super.init()
    }
    
    // MARK: - SKStoreProductViewControllerDelegate
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        viewController.dismiss(animated: true)
    }
    
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
    
    // MARK: - Ads Dialog Tracking
    func incrementAppOpenedAdsTimes() {
        let currentTimes = getAppOpenedAdsTimes()
        setAppOpenedAdsTimes(currentTimes + 1)
    }
    
    func getAppOpenedAdsTimes() -> Int {
        return userDefaults.integer(forKey: appOpenedAdsTimesKey)
    }
    
    private func setAppOpenedAdsTimes(_ times: Int) {
        userDefaults.set(times, forKey: appOpenedAdsTimesKey)
    }
    
    func shouldShowAdsDialog() -> Bool {
        // Only show if not dismissed and reached target times
        if isAdsDialogDismissed() {
            return false
        }
        return getAppOpenedAdsTimes() >= targetAdsDialogTimes
    }
    
    func markAdsDialogDismissed() {
        userDefaults.set(true, forKey: adsDialogDismissedKey)
    }
    
    func markAdsDialogPermanentlyDismissed() {
        // Mark as permanently dismissed (when premium is purchased)
        userDefaults.set(true, forKey: adsDialogDismissedKey)
    }
    
    func resetAdsDialogCounter() {
        // Reset counter when "Maybe Later" is clicked, so it can show again after 5 more opens
        setAppOpenedAdsTimes(0)
    }
    
    func isAdsDialogDismissed() -> Bool {
        return userDefaults.bool(forKey: adsDialogDismissedKey)
    }
    
    // MARK: - Debug Methods
    func resetRatingForTesting() {
        userDefaults.removeObject(forKey: appOpenedRateTimesKey)
        print("🔄 Rating state reset for testing")
    }
    
    func resetAdsDialogForTesting() {
        userDefaults.removeObject(forKey: appOpenedAdsTimesKey)
        userDefaults.removeObject(forKey: adsDialogDismissedKey)
        print("🔄 Ads dialog state reset for testing")
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
        // Use SKStoreProductViewController for reliable in-app App Store display
        // This works on both simulator and device
        DispatchQueue.main.async {
            let productViewController = SKStoreProductViewController()
            productViewController.delegate = self
            
            let parameters = [SKStoreProductParameterITunesItemIdentifier: "6753917936"]
            
            // Get the key window's root view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                  let rootViewController = window.rootViewController else {
                // If we can't get the view controller, try simple HTTPS URL fallback
                if let url = URL(string: "https://apps.apple.com/app/id6753917936") {
                    UIApplication.shared.open(url, options: [:], completionHandler: { success in
                        if !success {
                            print("Failed to open App Store URL")
                        }
                    })
                }
                return
            }
            
            // Find the topmost view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            productViewController.loadProduct(withParameters: parameters) { (success, error) in
                DispatchQueue.main.async {
                    if success {
                        topController.present(productViewController, animated: true)
                    } else {
                        // Fallback to simple HTTPS URL if SKStoreProductViewController fails
                        // This should work on simulator
                        if let url = URL(string: "https://apps.apple.com/app/id6753917936") {
                            UIApplication.shared.open(url, options: [:], completionHandler: { success in
                                if !success {
                                    print("Failed to open App Store URL: \(error?.localizedDescription ?? "Unknown error")")
                                }
                            })
                        }
                    }
                }
            }
        }
    }
}
