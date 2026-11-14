import SwiftUI
import Combine
import Kingfisher

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
    @State private var gamesByName: [String: Game] = [:]
    @State private var isGameDetailsPresented = false
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var adMobService = AdMobService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var cancellables = Set<AnyCancellable>()
    
    private let networkService = NetworkService.shared
    private let tabs = ["Switch", "Switch 2", "3DS", "Wii U"]
    
    var body: some View {
        NavigationView {
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
                            GameCompatibilityCard(
                                game: game,
                                isGameDetailsPresented: $isGameDetailsPresented
                            )
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
        .navigationTitle(amiibo.name)
        .toolbar(.hidden, for: .navigationBar)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(.appRed)
        .onAppear {
            reloadCachedGames()
            loadCompatibilityData()
            // Show interstitial ad (every 3rd time) - only if ads not purchased
            if !purchaseManager.isNoAdsPurchased {
                adMobService.showInterstitialAd {
                    // Ad dismissed or not shown
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .gamesCacheDidChange).receive(on: DispatchQueue.main)) { _ in
            reloadCachedGames()
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
    
    
    private func reloadCachedGames() {
        gamesByName = GameDisplay.gamesByNormalizedName(CoreDataService.shared.getAllGames())
    }

    private func compatibilityItem(name: String, usage: [AmiiboUsage], index: Int) -> GameCompatibilityItem {
        GameCompatibilityItem(
            id: "\(selectedTab)-\(index)-\(name)",
            name: name,
            usage: usage.first?.usage ?? "",
            write: usage.first?.write ?? false,
            matchingGame: GameDisplay.matchingGame(named: name, in: gamesByName)
        )
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
            return amiiboGames.gamesSwitch.enumerated().map { index, game in
                compatibilityItem(name: game.gameName, usage: game.amiiboUsage, index: index)
            }
        case 1: // Switch 2
            return amiiboGames.gamesSwitch2.enumerated().map { index, game in
                compatibilityItem(name: game.gameName, usage: game.amiiboUsage, index: index)
            }
        case 2: // 3DS
            return amiiboGames.games3DS.enumerated().map { index, game in
                compatibilityItem(name: game.gameName, usage: game.amiiboUsage, index: index)
            }
        case 3: // Wii U
            return amiiboGames.gamesWiiU.enumerated().map { index, game in
                compatibilityItem(name: game.gameName, usage: game.amiiboUsage, index: index)
            }
        default:
            return []
        }
    }
    
    struct GameCompatibilityItem: Identifiable {
        let id: String
        let name: String
        let usage: String
        let write: Bool
        let matchingGame: Game?
    }
}

struct GameCompatibilityCard: View {
    let game: AmiiboCompatibilityView.GameCompatibilityItem
    @Binding var isGameDetailsPresented: Bool
    @State private var isExpanded = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                coverImage
                    .frame(width: 80, height: 80)
                    .clipped()
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 12,
                            bottomLeadingRadius: isExpanded ? 0 : 12,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                    )
                
                HStack(alignment: .center, spacing: 8) {
                    Text(game.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
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
                .padding(.leading, 12)
                .padding(.trailing, 10)
            }
            .frame(height: 80)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
            
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
                    
                    if let matchingGame = game.matchingGame {
                        NavigationLink(destination: GameDetailsView(
                            game: matchingGame,
                            isGameDetailsPresented: $isGameDetailsPresented
                        )) {
                            Text("Game Details")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(themeManager.isDarkMode ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(themeManager.isDarkMode ? Color.white : Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
        }
        .background(themeManager.isDarkMode ? Color.black : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var coverImage: some View {
        if let imageUrlString = game.matchingGame?.backgroundImage,
           !imageUrlString.isEmpty,
           let imageUrl = URL(string: imageUrlString) {
            KFImage(imageUrl)
                .placeholder { coverPlaceholder }
                .onFailure { _ in }
                .fade(duration: 0.15)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "gamecontroller")
                    .foregroundColor(.gray)
            )
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
