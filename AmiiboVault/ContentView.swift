import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var amiiboViewModel = AmiiboListViewModel()
    @State private var isDetailsPresented = false
    @State private var isGameDetailsPresented = false
    
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
            // Set tab bar appearance to match our custom design
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.black
            
            // Set selected item color
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.red
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.red]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
}
