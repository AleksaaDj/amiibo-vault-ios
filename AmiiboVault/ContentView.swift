import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var amiiboViewModel = AmiiboListViewModel()
    @State private var isDetailsPresented = false
    @State private var isGameDetailsPresented = false
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                (themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Dismiss keyboard when tapping anywhere on the main view
                        dismissKeyboard()
                    }
                
                // Main Content - Keep all views alive to preserve state
                ZStack {
                // Amiibo List (always present, just hidden)
                AmiiboListView(viewModel: amiiboViewModel, isDetailsPresented: $isDetailsPresented)
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)
                
                // Posts View
                PostsView()
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)
                
                // Games View
                GamesView(isGameDetailsPresented: $isGameDetailsPresented)
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)
                
                // Collection View
                CollectionView(viewModel: amiiboViewModel, isDetailsPresented: $isDetailsPresented)
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)
                
                // Scanner View
                AmiiboScannerView(isDetailsPresented: $isDetailsPresented, viewModel: amiiboViewModel)
                    .opacity(selectedTab == 4 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 4)
                }
                .animation(.easeInOut(duration: 0.2), value: selectedTab)
            
            // Custom Bottom Navigation Bar
            if !isDetailsPresented && !isGameDetailsPresented {
                VStack {
                    Spacer()
                    CustomBottomNavigationBar(selectedTab: $selectedTab)
                }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Custom Bottom Navigation Bar
struct CustomBottomNavigationBar: View {
    @Binding var selectedTab: Int
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Home Tab
            TabButton(
                icon: "magnifyingglass",
                label: "Home",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            
            // Posts Tab
            TabButton(
                icon: "square.and.pencil",
                label: "Posts",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            
            // Scanner Tab (Center)
            TabButton(
                icon: "nfc_icon",
                label: "Scanner",
                isSelected: selectedTab == 4,
                action: { selectedTab = 4 }
            )
            
            // Games Tab
            TabButton(
                icon: "gamecontroller",
                label: "Games",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            
            // Collection Tab
            TabButton(
                icon: "star.fill",
                label: "Collection",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .frame(height: 90)
        .background(themeManager.isDarkMode ? Color.black : Color.black)
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if icon == "nfc_icon" || icon == "nfc_icon_white" {
                    Image(isSelected ? "nfc_icon" : "nfc_icon_white")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .appRed : (themeManager.isDarkMode ? .white : .white))
                }
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isSelected ? .appRed : (themeManager.isDarkMode ? .white : .white))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}


#Preview {
    ContentView()
}
