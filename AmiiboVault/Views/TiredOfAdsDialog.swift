//
//  TiredOfAdsDialog.swift
//  AmiiboVault
//
//  Dialog shown after app is opened 3 times to promote removing ads
//

import SwiftUI

struct TiredOfAdsDialog: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void
    let onRemoveAds: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // When tapping outside, treat it like "Maybe Later" - reset counter
                    dismissDialog()
                }
            
            // Dialog content
            VStack(spacing: 0) {
                // Header with icon
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.appRed.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.appRed)
                    }
                    
                    Text("Tired of Ads?")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    
                    Text("Enjoy an ad-free experience and unlock all premium features with one purchase!")
                        .font(.subheadline)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                
                // Benefits list
                VStack(alignment: .leading, spacing: 12) {
                    BenefitRow(icon: "checkmark.circle.fill", text: "Remove all ads forever")
                    BenefitRow(icon: "antenna.radiowaves.left.and.right", text: "Enable NFC scanning")
                    BenefitRow(icon: "star.fill", text: "All future premium features included")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                
                // Buttons
                VStack(spacing: 12) {
                    // Get Premium Button
                    Button(action: {
                        analyticsService.logEvent("tired_of_ads_premium_clicked", name: "tired_of_ads_premium_clicked")
                        onRemoveAds()
                        dismissDialog()
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Get Premium")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 14)
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
                    
                    // Individual options hint
                    Text("Individual options also available")
                        .font(.caption)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.5) : .gray.opacity(0.7))
                        .padding(.top, 4)
                    
                    // Dismiss Button
                    Button(action: {
                        dismissDialog()
                    }) {
                        HStack {
                            Spacer()
                            Text("Maybe Later")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .gray)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(themeManager.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.22) : Color.white)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
    
    private func dismissDialog() {
        withAnimation {
            isPresented = false
        }
        onDismiss()
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appRed)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.9) : .black)
            
            Spacer()
        }
    }
}

#Preview {
    TiredOfAdsDialog(
        isPresented: .constant(true),
        onDismiss: {},
        onRemoveAds: {}
    )
}

