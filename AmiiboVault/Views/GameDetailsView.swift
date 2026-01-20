import SwiftUI
import Kingfisher

struct GameDetailsView: View {
    let game: Game
    @Binding var isGameDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingScreenshots = false
    @State private var selectedScreenshot: Screenshot?
    @StateObject private var adMobService = AdMobService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Game Image
                // Use Kingfisher like the rest of the app (matches Android's Coil approach)
                if let imageUrlString = game.backgroundImage, !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) {
                    KFImage(imageUrl)
                        .placeholder {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                )
                        }
                        .onFailure { _ in
                            // Handle failure silently, placeholder will show
                        }
                        .fade(duration: 0.15)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .padding(.top, 20)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                        .frame(maxHeight: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .padding(.top, 20)
                }
                
                VStack(spacing: 20) {
                    // Game Title - Centered
                    Text(game.name ?? "Unknown Game")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    
                    // Game Stats - Centered
                    HStack(spacing: 30) {
                        if let rating = game.rating {
                            VStack(spacing: 4) {
                                Text("Rating")
                                    .font(.caption)
                                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .secondary)
                                Text(String(format: "%.1f", rating))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.isDarkMode ? .white : .appRed)
                            }
                        }
                        
                        if let metacritic = game.metacritic {
                            VStack(spacing: 4) {
                                Text("Metacritic")
                                    .font(.caption)
                                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .secondary)
                                Text("\(metacritic)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(themeManager.isDarkMode ? .white : .appRed)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    
                    // Release Date
                    if let released = game.released {
                        HStack {
                            Spacer()
                            Text("Released: \(formatReleaseDate(released))")
                                .font(.subheadline)
                                .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Game Details Card
                    VStack(alignment: .leading, spacing: 16) {
                        if let genres = game.genres, !genres.isEmpty {
                            DetailRowView(
                                label: "Genres",
                                value: genres.compactMap { $0.name }.joined(separator: ", "),
                                icon: "tag.fill",
                                iconColor: .purple,
                                themeManager: themeManager
                            )
                        }
                        
                        if let ratingCount = game.ratingsCount, ratingCount > 0 {
                            DetailRowView(
                                label: "Rating Count",
                                value: "\(ratingCount) ratings",
                                icon: "person.3.fill",
                                iconColor: .orange,
                                themeManager: themeManager
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.isDarkMode ? Color.black.opacity(0.3) : Color.gray.opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                    
                    // Screenshots Section
                    if let screenshots = game.shortScreenshots, !screenshots.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Screenshots")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(screenshots.prefix(5)) { screenshot in
                                        Button(action: {
                                            selectedScreenshot = screenshot
                                        }) {
                                            if let imageUrlString = screenshot.image, !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) {
                                                KFImage(imageUrl)
                                                    .placeholder {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .overlay(
                                                                ProgressView()
                                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                            )
                                                    }
                                                    .onFailure { _ in
                                                        // Handle failure silently
                                                    }
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 160, height: 120)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            } else {
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .overlay(
                                                        ProgressView()
                                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    )
                                                    .frame(width: 160, height: 120)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.bottom, 30)
                        
                        // Small Banner Ad at bottom - only if ads not purchased
                        if !purchaseManager.isNoAdsPurchased {
                            FullWidthBannerAdView(adUnitID: adMobService.getBannerAdUnitID())
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Open Amazon link like Android implementation
                    if let gameName = game.name {
                        let filteredName = gameName.replacingOccurrences(of: "&", with: " ")
                            .replacingOccurrences(of: " ", with: "+")
                        let amazonUrl = "https://www.amazon.com/s?k=\(filteredName)+nintendo+game&tag=amiibovault-20"
                        if let url = URL(string: amazonUrl) {
                            UIApplication.shared.open(url)
                        }
                    }
                }) {
                    Image(systemName: "cart")
                        .foregroundColor(.appRed)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .onAppear {
            isGameDetailsPresented = true
            // Show interstitial ad (every 3rd time) - only if ads not purchased
            if !purchaseManager.isNoAdsPurchased {
                adMobService.showInterstitialAd {
                    // Ad dismissed or not shown
                }
            }
        }
        .onDisappear {
            isGameDetailsPresented = false
        }
        .fullScreenCover(item: $selectedScreenshot) { screenshot in
            FullScreenScreenshotView(screenshot: screenshot)
        }
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM dd, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}

// MARK: - Detail Row View
struct DetailRowView: View {
    let label: String
    let value: String
    let icon: String
    let iconColor: Color
    let themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
            }
            
            Spacer()
        }
    }
}

// MARK: - Full Screen Screenshot View
struct FullScreenScreenshotView: View {
    let screenshot: Screenshot
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let imageUrlString = screenshot.image, !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) {
                KFImage(imageUrl)
                    .placeholder {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                    .onFailure { _ in
                        // Handle failure silently
                    }
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1.0), 4.0)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1.0 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scale = 1.0
                                    offset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onTapGesture(count: 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if scale > 1.0 {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    scale = 2.0
                }
            }
        }
    }
}

// MARK: - Screenshots View
struct ScreenshotsView: View {
    let screenshots: [Screenshot]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(screenshots) { screenshot in
                        if let imageUrlString = screenshot.image, !imageUrlString.isEmpty, let imageUrl = URL(string: imageUrlString) {
                            KFImage(imageUrl)
                                .placeholder {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .onFailure { _ in
                                    // Handle failure silently
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Screenshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appRed)
                }
            }
        }
    }
}