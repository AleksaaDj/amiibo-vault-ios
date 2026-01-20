import SwiftUI
import FirebaseAnalytics

struct SupportView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var ratingManager = RatingManager.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text("Support AmiiVault")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .padding(.top, 16)
                    
                    // Description - focus on support, feedback, and community
                    Text("Love using AmiiVault? Your support helps us grow and build an even better app! Your feedback and ratings are invaluable, and we're grateful for this amazing community. Thank you!")
                        .font(.body)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                        .lineSpacing(4)
                    
                    Spacer(minLength: 8)
                    
                    // Divider
                    Divider()
                        .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    // Premium Section
                    // Show premium option only if user hasn't purchased premium
                    // Note: Even if they have both individual purchases, they can still buy premium for future features
                    if !purchaseManager.isPremiumPurchased {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Go Premium")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            
                            Text("Get everything: Remove ads, enable scanner, and unlock all future premium features automatically!")
                                .font(.subheadline)
                                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                                .lineSpacing(3)
                            
                            Button(action: {
                                Task {
                                    await purchaseManager.makePremiumPurchase()
                                    analyticsService.logEvent("premium_purchase_clicked", name: "premium_button_clicked")
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Get Premium")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.appRed, Color.appRed.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: Color.appRed.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.appRed.opacity(0.3), lineWidth: 1)
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Premium Active")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            }
                            Text("You have access to all current and future premium features!")
                                .font(.subheadline)
                                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Spacer(minLength: 2)
                    
                    // Divider
                    Divider()
                        .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    // Individual Purchases Section (only show if user doesn't have premium)
                    // Even if they have both individual purchases, they can still see this section
                    // but buttons will be disabled if already purchased
                    if !purchaseManager.isPremiumPurchased {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Individual Features")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            
                            VStack(spacing: 6) {
                                // Remove Ads Button
                                Button(action: {
                                    Task {
                                        await purchaseManager.makeNoAdsPurchase()
                                        analyticsService.logEvent(AnalyticsService.AMIIBO_REMOVE_ADS, name: "remove_ads_button_clicked")
                                    }
                                }) {
                                    HStack {
                                        Spacer()
                                        Text(purchaseManager.isNoAdsPurchased ? "Ads Removed ✓" : "Remove Ads")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .background(purchaseManager.isNoAdsPurchased ? Color.gray : Color.black)
                                    .cornerRadius(12)
                                }
                                .disabled(purchaseManager.isNoAdsPurchased)
                                
                                // Enable Scanner Button
                                Button(action: {
                                    Task {
                                        await purchaseManager.makeAmiiboScanPurchase()
                                        analyticsService.logEvent(AnalyticsService.AMIIBO_ENABLE_SCANNER, name: "enable_scanner_button_clicked")
                                    }
                                }) {
                                    HStack {
                                        Spacer()
                                        Text(purchaseManager.isAmiiboScanPurchased ? "Scanner Enabled ✓" : "Enable Scanner")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 12)
                                    .background(purchaseManager.isAmiiboScanPurchased ? Color.gray : Color.black)
                                    .cornerRadius(12)
                                }
                                .disabled(purchaseManager.isAmiiboScanPurchased)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
                        )
                        
                        Spacer(minLength: 2)
                    }
                    
                    // Divider
                    Divider()
                        .background(themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.gray.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    // Support & Other Actions Section
                    VStack(alignment: .leading, spacing: 6) {
                        Text("More Ways to Help")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        
                        VStack(spacing: 6) {
                            // Restore Purchases Button
                            Button(action: {
                                Task {
                                    await purchaseManager.restorePurchases()
                                    analyticsService.logEvent("restore_purchases_clicked", name: "restore_purchases_clicked")
                                }
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Restore Purchases")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                            }
                            
                            // Rate App Button - moved to top as it's the easiest action
                            Button(action: {
                                rateApp()
                            }) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Rate AmiiVault")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .background(Color.black)
                                .cornerRadius(12)
                            }
                            
                            // Ko-fi Support Button - made optional and less pushy
                            Button(action: {
                                openKoFi()
                            }) {
                                HStack(spacing: 12) {
                                    // Ko-fi icon (coffee cup with heart)
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 24, height: 24)
                                        
                                        Image(systemName: "cup.and.saucer.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                        
                                        Image(systemName: "heart.fill")
                                            .font(.system(size: 8))
                                            .foregroundColor(.red)
                                            .offset(x: 2, y: 2)
                                    }
                                    
                                    Text("Buy me a coffee (optional)")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.gray.opacity(0.1))
                    )
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
            .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Log screen view
                analyticsService.logScreenView("support_screen", screenClass: "SupportView")
                analyticsService.logEvent(AnalyticsService.AMIIBO_SUPPORT_SCREEN_OPENED)
            }
    }
    
    private func rateApp() {
        ratingManager.openAppStoreRating()
        analyticsService.logEvent(AnalyticsService.AMIIBO_RATE, name: "rate_button_clicked")
    }
    
    private func openKoFi() {
        if let url = URL(string: "https://ko-fi.com/softwavegames") {
            UIApplication.shared.open(url)
            analyticsService.logEvent(AnalyticsService.AMIIBO_KOFI, name: "kofi_button_clicked")
        }
    }
}

#Preview {
    SupportView()
}
