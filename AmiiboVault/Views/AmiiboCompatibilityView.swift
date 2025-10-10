import SwiftUI

struct AmiiboCompatibilityView: View {
    let amiibo: Amiibo
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var showError = false
    @StateObject private var themeManager = ThemeManager.shared
    
    private let tabs = ["Switch", "3DS", "Wii U"]
    
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
                        ForEach(sampleGames(for: selectedTab), id: \.self) { game in
                            GameCompatibilityCard(game: game)
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
        }
    }
    
    
    private func loadCompatibilityData() {
        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            // For now, we'll show sample data
            // In a real implementation, this would fetch from an API
        }
    }
    
    private func sampleGames(for tab: Int) -> [String] {
        switch tab {
        case 0: // Switch
            return [
                "Super Smash Bros. Ultimate",
                "The Legend of Zelda: Breath of the Wild",
                "Animal Crossing: New Horizons",
                "Mario Kart 8 Deluxe",
                "Splatoon 2"
            ]
        case 1: // 3DS
            return [
                "Super Smash Bros. for Nintendo 3DS",
                "Animal Crossing: New Leaf",
                "Mario Kart 7",
                "Fire Emblem Fates"
            ]
        case 2: // Wii U
            return [
                "Super Smash Bros. for Wii U",
                "Mario Kart 8",
                "Splatoon",
                "Animal Crossing: amiibo Festival"
            ]
        default:
            return []
        }
    }
}

struct GameCompatibilityCard: View {
    let game: String
    @State private var isExpanded = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            HStack {
                Text(game)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("Compatible")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
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
                        
                        Text(getUsageDescription(for: game))
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
    
    private func getUsageDescription(for game: String) -> String {
        // This would normally come from the API
        // For now, returning sample descriptions based on game
        switch game {
        case "Super Smash Bros. Ultimate":
            return "Use this amiibo to train a CPU fighter that learns from your playstyle. The fighter will level up and become stronger as you battle together."
        case "The Legend of Zelda: Breath of the Wild":
            return "Scan this amiibo to receive special items, weapons, and materials. Some amiibos unlock exclusive armor sets and unique weapons."
        case "Animal Crossing: New Horizons":
            return "Invite this character to your island as a special visitor. They may bring unique furniture, clothing, or other exclusive items."
        case "Mario Kart 8 Deluxe":
            return "Unlock a Mii racing suit based on this character. Each amiibo provides a unique costume with special abilities and appearance."
        case "Splatoon 2":
            return "Receive exclusive gear and weapons. Some amiibos unlock special outfits that can't be obtained through normal gameplay."
        case "Super Smash Bros. for Nintendo 3DS":
            return "Train a CPU fighter that adapts to your fighting style. The fighter will gain experience and improve over time."
        case "Animal Crossing: New Leaf":
            return "Invite this character to your town. They may bring special furniture, clothing, or other exclusive items for your home."
        case "Mario Kart 7":
            return "Unlock a Mii racing suit and special kart parts. Each amiibo provides unique customization options for your racer."
        case "Fire Emblem Fates":
            return "Receive special items and support conversations. Some amiibos unlock exclusive characters or story content."
        case "Super Smash Bros. for Wii U":
            return "Train a CPU fighter that learns from your battles. The fighter will develop unique fighting patterns and strategies."
        case "Mario Kart 8":
            return "Unlock Mii racing suits and special kart customization options. Each amiibo provides unique visual and performance upgrades."
        case "Splatoon":
            return "Receive exclusive gear, weapons, and special missions. Some amiibos unlock unique clothing and equipment sets."
        case "Animal Crossing: amiibo Festival":
            return "Add this character to your amiibo Festival board game. Each character has unique abilities and special events."
        default:
            return "This amiibo can be used with this game to unlock special content, characters, or features. Tap the amiibo to the NFC reader to activate its functionality."
        }
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
