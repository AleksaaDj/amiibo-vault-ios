import SwiftUI

struct SupportView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Support Amiibo Vault development")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .padding(.top, 20)
                    
                    // Description paragraphs
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Amiibo Vault relies on your generous support for its continued development. Consider making a small donation to our team by purchasing us a coffee by clicking a button below.")
                            .font(.body)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                            .lineSpacing(4)
                        
                        Text("Your rating of Amiibo Vault on the App Store would also serve as a valuable contribution, providing us with vital feedback to adapt and improve our offerings.")
                            .font(.body)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .gray)
                            .lineSpacing(4)
                        
                        Text("Your invaluable support ensures we can continue to make Amiibo Vault even more enjoyable for all the Amiibo enthusiasts out there. Thank you very much.")
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
                                Text("Rate Amiibo Vault")
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
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id6753917936") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openKoFi() {
        if let url = URL(string: "https://ko-fi.com/softwavegames") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    SupportView()
}
