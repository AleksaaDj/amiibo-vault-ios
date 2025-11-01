import SwiftUI
import FirebaseAnalytics

struct SupportView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var ratingManager = RatingManager.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Support AmiiVault development")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .padding(.top, 20)
                    
                    // Description paragraphs
                    VStack(alignment: .leading, spacing: 16) {
                        Text("AmiiVault relies on your generous support for its continued development. Consider making a small donation to our team by purchasing us a coffee by clicking a button below.")
                            .font(.body)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                            .lineSpacing(4)
                        
                        Text("Your rating of AmiiVault on the App Store would also serve as a valuable contribution, providing us with vital feedback to adapt and improve our offerings.")
                            .font(.body)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                            .lineSpacing(4)
                        
                        Text("Your invaluable support ensures we can continue to make AmiiVault even more enjoyable for all the Amiibo enthusiasts out there. Thank you very much.")
                            .font(.body)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                            .lineSpacing(4)
                    }
                    
                    Spacer(minLength: 20)
                    
                    // Action Buttons
                    VStack(spacing: 16) {
                        // Rate App Button
                        Button(action: {
                            rateApp()
                        }) {
                            HStack {
                                Spacer()
                                Text("Rate AmiiVault")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        
                        // Ko-fi Support Button
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
                                
                                Text("Support me on Ko-fi")
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
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
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
