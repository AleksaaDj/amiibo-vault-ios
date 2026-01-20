import SwiftUI
import FirebaseAnalytics
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var amiiboViewModel = AmiiboListViewModel()
    @State private var isDetailsPresented = false
    @State private var isGameDetailsPresented = false
    @StateObject private var ratingManager = RatingManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingTiredOfAdsDialog = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            NavigationView {
                AmiiboListView(viewModel: amiiboViewModel, isDetailsPresented: $isDetailsPresented)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Home")
            }
            .tag(0)
            
            // Posts Tab
            NavigationView {
                PostsView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "square.and.pencil")
                Text("Posts")
            }
            .tag(1)
            
            // Scanner Tab (Center)
            NavigationView {
                AmiiboScannerView(isDetailsPresented: $isDetailsPresented, viewModel: amiiboViewModel)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text("Scanner")
            }
            .tag(4)
            
            // Games Tab
            NavigationView {
                GamesView(isGameDetailsPresented: $isGameDetailsPresented)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "gamecontroller")
                Text("Games")
            }
            .tag(2)
            
            // Collection Tab
            NavigationView {
                CollectionView(viewModel: amiiboViewModel, isDetailsPresented: $isDetailsPresented)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "star.fill")
                Text("Collection")
            }
            .tag(3)
        }
        .accentColor(.appRed)
        .onAppear {
            // Configure tab bar appearance with black background in dark mode
            configureTabBarAppearance()
            
            // Handle rating dialog logic
            handleRatingDialog()
            
            // Handle "Tired of ads" dialog logic
            handleTiredOfAdsDialog()
        }
        .onChange(of: themeManager.isDarkMode) { _ in
            // Update tab bar appearance when theme changes
            configureTabBarAppearance()
        }
        .overlay {
            // Tired of Ads Dialog
            if showingTiredOfAdsDialog {
                TiredOfAdsDialog(
                    isPresented: $showingTiredOfAdsDialog,
                    onDismiss: {
                        // User clicked "Maybe Later" - mark as permanently dismissed (never show again)
                        ratingManager.markAdsDialogPermanentlyDismissed()
                    },
                    onRemoveAds: {
                        // User clicked "Get Premium" - mark as permanently dismissed
                        ratingManager.markAdsDialogPermanentlyDismissed()
                        Task {
                            await purchaseManager.makePremiumPurchase()
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Tab Bar Appearance Configuration
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Set background color - always black
        appearance.backgroundColor = UIColor.black
        
        // Set selected item color (red)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.systemRed
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemRed]
        
        // Set unselected item color
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
        
        // Apply to all tab bars
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    // MARK: - Rating Dialog Logic
    private func handleRatingDialog() {
        // Increment app opened times
        ratingManager.incrementAppOpenedTimes()
        
        // Check if we should show rating dialog
        if ratingManager.shouldShowRatingDialog() {
            // Add a small delay to ensure the UI is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Use production method for App Store
                ratingManager.requestRating()
            }
        }
    }
    
    // MARK: - Tired of Ads Dialog Logic
    private func handleTiredOfAdsDialog() {
        // Only show if ads are not purchased
        guard !purchaseManager.isNoAdsPurchased && !purchaseManager.isPremiumPurchased else {
            return
        }
        
        // Increment app opened times for ads dialog
        ratingManager.incrementAppOpenedAdsTimes()
        
        // Check if we should show "Tired of ads" dialog
        if ratingManager.shouldShowAdsDialog() {
            // Add a small delay to ensure the UI is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingTiredOfAdsDialog = true
            }
        }
    }
}

#Preview {
    ContentView()
}
