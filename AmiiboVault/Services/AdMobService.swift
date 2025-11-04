import Foundation
import GoogleMobileAds
import SwiftUI
import Combine

class AdMobService: NSObject, ObservableObject {
    static let shared = AdMobService()
    
    // Ad Unit IDs
    private let interstitialAdUnitID = "ca-app-pub-3564715368914014/9379723307" // Production interstitial
    private let bannerAdUnitID = "ca-app-pub-3564715368914014/3005886648" // Production banner
    
    @Published var interstitialAd: InterstitialAd?
    @Published var isAdLoaded = false
    
    private var interstitialClickTimes = 0
    
    override init() {
        super.init()
        loadInterstitialAd()
    }
    
    func loadInterstitialAd() {
        let request = Request()
        InterstitialAd.load(with: interstitialAdUnitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isAdLoaded = false
                    return
                }
                self?.interstitialAd = ad
                self?.isAdLoaded = true
            }
        }
    }
    
    func showInterstitialAd(completion: @escaping () -> Void) {
        interstitialClickTimes += 1
        
        // Show ad every 8th time
        if interstitialClickTimes % 8 == 0 {
            if let ad = interstitialAd {
                ad.fullScreenContentDelegate = self
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    ad.present(from: rootViewController)
                } else {
                    completion()
                }
            } else {
                completion()
            }
        } else {
            completion()
        }
    }
    
    func showInterstitialAdImmediately(completion: @escaping () -> Void) {
        // Show ad immediately (for collection image generation)
        if let ad = interstitialAd {
            ad.fullScreenContentDelegate = self
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                ad.present(from: rootViewController)
            } else {
                completion()
            }
        } else {
            completion()
        }
    }
    
    func getBannerAdUnitID() -> String {
        return bannerAdUnitID
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Load a new ad after the current one is dismissed
        loadInterstitialAd()
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        loadInterstitialAd()
    }
}
