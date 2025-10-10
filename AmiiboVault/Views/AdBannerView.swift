import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize
    
    init(adUnitID: String, adSize: AdSize = AdSizeBanner) {
        self.adUnitID = adUnitID
        self.adSize = adSize
    }
    
    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.windows.first?.rootViewController
        return bannerView
    }
    
    func updateUIView(_ bannerView: BannerView, context: Context) {
        let request = Request()
        bannerView.load(request)
    }
}

// MARK: - Large Banner Ad
struct LargeBannerAdView: View {
    let adUnitID: String
    
    var body: some View {
        AdBannerView(adUnitID: adUnitID, adSize: AdSizeLargeBanner)
            .frame(height: 100)
    }
}

// MARK: - Full Width Banner Ad
struct FullWidthBannerAdView: View {
    let adUnitID: String
    
    var body: some View {
        AdBannerView(adUnitID: adUnitID, adSize: AdSizeBanner)
            .frame(height: 50)
    }
}
