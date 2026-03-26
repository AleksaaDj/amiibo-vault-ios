import SwiftUI
import Combine

struct AmiiboCompatibilityView: View {
    let amiibo: Amiibo
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    @State private var amiiboGames: AmiiboGames?
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var adMobService = AdMobService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    private let networkService = NetworkService.shared
    private let tabs = ["Switch", "Switch 2", "3DS", "Wii U"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.appRed)
                        .font(.title2)
                }
                
                Spacer()
                
                Text(amiibo.name)
                    .foregroundColor(themeManager.isDarkMode ? .white : .appRed)
                    .font(.headline)
                
                Spacer()
                
                // Empty space to balance the back button
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(.systemBackground))
            
            // Tab Selector
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        selectedTab = index
                    }) {
                        Text(tabs[index])
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(selectedTab == index ? .white : .appRed)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedTab == index ? Color.appRed : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.appRed, lineWidth: selectedTab == index ? 0 : 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(1.5)
                    Spacer()
                }
            } else if showError {
                VStack {
                    Spacer()
                    Text("No compatibility data available")
                        .font(.headline)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                // Games List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(getGames(for: selectedTab), id: \.id) { game in
                            GameCompatibilityCard(game: game)
                        }
                        
                        // Banner Ad - only if ads not purchased
                        if !purchaseManager.isNoAdsPurchased {
                            FullWidthBannerAdView(adUnitID: adMobService.getBannerAdUnitID())
                                .padding(.horizontal, 20)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .onAppear {
            loadCompatibilityData()
            // Show interstitial ad (every 3rd time) - only if ads not purchased
            if !purchaseManager.isNoAdsPurchased {
                adMobService.showInterstitialAd {
                    // Ad dismissed or not shown
                }
            }
        }
        .alert("Compatibility Data Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
            Button("Retry") {
                loadCompatibilityData()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    
    private func loadCompatibilityData() {
        isLoading = true
        showError = false
        
        networkService.fetchAmiiboConsoles(tail: amiibo.tail)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        var errorDesc = error.localizedDescription
                        var errorDetails = "Error type: \(type(of: error))"
                        
                        // Get more details if it's an NSError
                        if let nsError = error as NSError? {
                            errorDetails += "\nDomain: \(nsError.domain)"
                            errorDetails += "\nCode: \(nsError.code)"
                            
                            // Get debug description if available
                            if let debugDesc = nsError.userInfo["NSDebugDescription"] as? String {
                                errorDetails += "\n\nDebug: \(debugDesc)"
                            }
                            
                            // Get coding path if available
                            if let codingPath = nsError.userInfo["NSCodingPath"] as? [String] {
                                errorDetails += "\n\nPath: \(codingPath.joined(separator: " -> "))"
                            }
                            
                            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                                errorDetails += "\n\nUnderlying error: \(underlyingError.localizedDescription)"
                            }
                        }
                        
                        errorMessage = "Failed to load compatibility data:\n\n\(errorDesc)\n\n\(errorDetails)"
                        showError = true
                        showErrorAlert = true
                    }
                },
                receiveValue: { games in
                    isLoading = false
                    if let firstAmiibo = games.amiibo.first {
                        amiiboGames = firstAmiibo
                        if firstAmiibo.games3DS.isEmpty && firstAmiibo.gamesSwitch.isEmpty && firstAmiibo.gamesSwitch2.isEmpty && firstAmiibo.gamesWiiU.isEmpty {
                            showError = true
                        }
                    } else {
                        showError = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func getGames(for tab: Int) -> [GameCompatibilityItem] {
        guard let amiiboGames = amiiboGames else { return [] }
        
        switch tab {
        case 0: // Switch
            return amiiboGames.gamesSwitch.map { game in
                GameCompatibilityItem(
                    name: game.gameName,
                    usage: game.amiiboUsage.first?.usage ?? "",
                    write: game.amiiboUsage.first?.write ?? false
                )
            }
        case 1: // Switch 2
            return amiiboGames.gamesSwitch2.map { game in
                GameCompatibilityItem(
                    name: game.gameName,
                    usage: game.amiiboUsage.first?.usage ?? "",
                    write: game.amiiboUsage.first?.write ?? false
                )
            }
        case 2: // 3DS
            return amiiboGames.games3DS.map { game in
                GameCompatibilityItem(
                    name: game.gameName,
                    usage: game.amiiboUsage.first?.usage ?? "",
                    write: game.amiiboUsage.first?.write ?? false
                )
            }
        case 3: // Wii U
            return amiiboGames.gamesWiiU.map { game in
                GameCompatibilityItem(
                    name: game.gameName,
                    usage: game.amiiboUsage.first?.usage ?? "",
                    write: game.amiiboUsage.first?.write ?? false
                )
            }
        default:
            return []
        }
    }
    
    struct GameCompatibilityItem: Identifiable {
        let id = UUID()
        let name: String
        let usage: String
        let write: Bool
    }
}

struct GameCompatibilityCard: View {
    let game: AmiiboCompatibilityView.GameCompatibilityItem
    @State private var isExpanded = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            HStack {
                Text(game.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if game.write {
                        Text("Read/Write")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text("Read Only")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.isDarkMode ? .white : .gray)
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Usage Description")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                        
                        Text(game.usage.isEmpty ? "No usage information available." : game.usage)
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.8) : .secondary)
                            .lineLimit(nil)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .background(themeManager.isDarkMode ? Color.black : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let viewModel = AmiiboListViewModel()
    let sampleAmiibo = Amiibo(
        amiiboSeries: "The Legend of Zelda",
        character: "Link",
        gameSeries: "The Legend of Zelda",
        head: "01000000",
        image: "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_01000000-034f0902.png",
        name: "8-Bit Link",
        release: Release(au: "03 Dec 2016", eu: "02 Dec 2016", jp: "01 Dec 2016", na: "02 Dec 2016"),
        tail: "034f0902",
        type: "Figure",
        featured: false,
        color: 0,
        isInCollection: false,
        isInWishlist: false
    )
    return AmiiboCompatibilityView(amiibo: sampleAmiibo, viewModel: viewModel, isDetailsPresented: .constant(false))
}
