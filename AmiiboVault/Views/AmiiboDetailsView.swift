import SwiftUI
import FirebaseAnalytics

struct AmiiboDetailsView: View {
    let amiibo: Amiibo
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    let amiiboList: [Amiibo]?
    @Environment(\.dismiss) private var dismiss
    @State private var showingSeriesView = false
    @State private var showingCompatibilityView = false
    @State private var currentIndex: Int = 0
    @State private var isInitialLoad = true
    @State private var cachedUpdatedList: [Amiibo]? = nil
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var adMobService = AdMobService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    // Initialize with optional list
    init(amiibo: Amiibo, viewModel: AmiiboListViewModel, isDetailsPresented: Binding<Bool>, amiiboList: [Amiibo]? = nil) {
        self.amiibo = amiibo
        self.viewModel = viewModel
        self._isDetailsPresented = isDetailsPresented
        self.amiiboList = amiiboList
        
        // Calculate initial index if list is provided
        if let list = amiiboList, let index = list.firstIndex(where: { $0.head == amiibo.head && $0.tail == amiibo.tail }) {
            self._currentIndex = State(initialValue: index)
        }
    }
    
    // Get the current amiibo from the list or fallback to the passed amiibo
    private var currentAmiibo: Amiibo {
        if let list = amiiboList, currentIndex < list.count {
            // Use pre-computed updated list for better performance
            let updatedList = computeUpdatedAmiiboList(list)
            if currentIndex < updatedList.count {
                return updatedList[currentIndex]
            }
            return list[currentIndex]
        }
        // Fallback to original behavior
        return viewModel.filteredAmiiboList.first { $0.head == amiibo.head && $0.tail == amiibo.tail } ?? amiibo
    }
    
    // Pre-compute updated amiibo list to avoid expensive lookups during rendering
    private func computeUpdatedAmiiboList(_ list: [Amiibo]) -> [Amiibo] {
        // Create a dictionary for O(1) lookup instead of O(n) for each item
        let filteredDict = Dictionary(uniqueKeysWithValues: viewModel.filteredAmiiboList.map { amiibo in
            (amiibo.head + amiibo.tail, amiibo)
        })
        
        return list.map { item in
            let key = item.head + item.tail
            return filteredDict[key] ?? item
        }
    }
    
    // Helper to get current amiibo from list for toolbar
    private func getCurrentAmiiboFromList(_ list: [Amiibo]) -> Amiibo {
        if currentIndex < list.count {
            let item = list[currentIndex]
            // Get updated data from view model
            return viewModel.filteredAmiiboList.first { $0.head == item.head && $0.tail == item.tail } ?? item
        }
        return amiibo
    }
    
    // Computed property for updated list (doesn't modify state)
    private var updatedList: [Amiibo] {
        guard let list = amiiboList, list.count > 1 else { return [] }
        if let cached = cachedUpdatedList {
            return cached
        }
        return computeUpdatedAmiiboList(list)
    }
    
    var body: some View {
        // Use TabView for swipe navigation if list is provided and has more than one item
        if let list = amiiboList, list.count > 1 {
            ZStack {
                // Background that extends behind tab bar to prevent white space
                (themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
                    .ignoresSafeArea(.container, edges: .bottom)
                
                TabView(selection: $currentIndex) {
                    ForEach(Array(updatedList.enumerated()), id: \.element.id) { index, updatedAmiibo in
                        AmiiboDetailContent(
                            amiibo: updatedAmiibo,
                            viewModel: viewModel,
                            isDetailsPresented: $isDetailsPresented,
                            showingSeriesView: $showingSeriesView,
                            showingCompatibilityView: $showingCompatibilityView,
                            shouldHandleAds: false // Ads handled at TabView level
                        )
                        .tag(index)
                        .id(updatedAmiibo.id) // Help SwiftUI optimize rendering
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
            .onAppear {
                // Cache the updated list when view appears (not during body evaluation)
                if cachedUpdatedList == nil, let list = amiiboList, list.count > 1 {
                    cachedUpdatedList = computeUpdatedAmiiboList(list)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        openAmazonLink(for: currentAmiibo)
                        analyticsService.logEvent(AnalyticsService.AMIIBO_AMAZON, id: currentAmiibo.head + currentAmiibo.tail, name: currentAmiibo.name)
                    }) {
                        Image(systemName: "cart")
                            .foregroundColor(.appRed)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Haptic feedback for wishlist action
                        HapticManager.shared.lightImpact()
                        let isAdding = !currentAmiibo.isInWishlist
                        viewModel.toggleWishlist(currentAmiibo)
                        let action = currentAmiibo.isInWishlist ? "remove_from_wishlist" : "add_to_wishlist"
                        if isAdding {
                            // Success haptic when adding to wishlist
                            HapticManager.shared.success()
                        }
                        analyticsService.logEvent(AnalyticsService.AMIIBO_ADD_WISHLIST, id: currentAmiibo.head + currentAmiibo.tail, name: action)
                    }) {
                        Image(systemName: currentAmiibo.isInWishlist ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.appRed)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
            .onChange(of: currentIndex) { newIndex in
                // Log analytics when swiping to a new amiibo
                if newIndex < updatedList.count {
                    let switchedAmiibo = updatedList[newIndex]
                    analyticsService.logEvent(AnalyticsService.AMIIBO_DETAILS_OPENED, id: switchedAmiibo.head + switchedAmiibo.tail, name: switchedAmiibo.name)
                    
                    // Increment ad counter when swiping (skip initial load)
                    if !isInitialLoad && !purchaseManager.isNoAdsPurchased {
                        adMobService.showInterstitialAd {
                            // Ad dismissed or not shown
                        }
                    }
                    isInitialLoad = false
                }
            }
            .onAppear {
                // Pre-compute and cache the updated list
                if cachedUpdatedList == nil {
                    cachedUpdatedList = computeUpdatedAmiiboList(list)
                }
                
                // Handle ad for initial load
                if !purchaseManager.isNoAdsPurchased {
                    adMobService.showInterstitialAd {
                        // Ad dismissed or not shown
                    }
                }
                isInitialLoad = false
            }
            .onChange(of: viewModel.filteredAmiiboList) { _ in
                // Clear cache when filtered list changes (e.g., collection status updated)
                cachedUpdatedList = nil
            }
            .sheet(isPresented: $showingSeriesView) {
                AmiiboSeriesView(gameSeries: currentAmiibo.gameSeries, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
            }
            .fullScreenCover(isPresented: $showingCompatibilityView) {
                AmiiboCompatibilityView(amiibo: currentAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
            }
        } else {
            // Single item view (original behavior)
            AmiiboDetailContent(
                amiibo: currentAmiibo,
                viewModel: viewModel,
                isDetailsPresented: $isDetailsPresented,
                showingSeriesView: $showingSeriesView,
                showingCompatibilityView: $showingCompatibilityView
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .sheet(isPresented: $showingSeriesView) {
                AmiiboSeriesView(gameSeries: currentAmiibo.gameSeries, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
            }
            .fullScreenCover(isPresented: $showingCompatibilityView) {
                AmiiboCompatibilityView(amiibo: currentAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
            }
        }
    }
    
    func openAmazonLink(for amiibo: Amiibo) {
        // Create Amazon search URL like Android implementation
        let amiiboName = amiibo.name.replacingOccurrences(of: "&", with: " ")
        let amiiboNameFiltered = amiiboName.replacingOccurrences(of: " ", with: "+")
        let amiiboType = amiibo.type
        let amiiboSeries = amiibo.gameSeries.replacingOccurrences(of: " ", with: "+")
        
        let amazonURL = "https://www.amazon.com/s?k=\(amiiboNameFiltered)+Amiibo+\(amiiboType)+\(amiiboSeries)&tag=amiibovault-20"
        
        if let url = URL(string: amazonURL) {
            UIApplication.shared.open(url)
        }
    }
    
}

// MARK: - Amiibo Detail Content (extracted for reuse)
struct AmiiboDetailContent: View {
    let amiibo: Amiibo
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @Binding var showingSeriesView: Bool
    @Binding var showingCompatibilityView: Bool
    let shouldHandleAds: Bool // Flag to control ad handling
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var adMobService = AdMobService.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showingSuccessAnimation = false
    
    init(amiibo: Amiibo, viewModel: AmiiboListViewModel, isDetailsPresented: Binding<Bool>, showingSeriesView: Binding<Bool>, showingCompatibilityView: Binding<Bool>, shouldHandleAds: Bool = true) {
        self.amiibo = amiibo
        self.viewModel = viewModel
        self._isDetailsPresented = isDetailsPresented
        self._showingSeriesView = showingSeriesView
        self._showingCompatibilityView = showingCompatibilityView
        self.shouldHandleAds = shouldHandleAds
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Amiibo Image
                AmiiboDetailsKingfisherImage(url: amiibo.image, width: 200, height: 200, cornerRadius: 8, shadowRadius: 10)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 20) {
                
                // Amiibo Name - Centered
                Text(amiibo.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 80)
                
                // Details Section
                VStack(spacing: 0) {
                    // Character
                    DetailRow(label: "Character", value: amiibo.character)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Game Series
                    DetailRow(label: "Game Series", value: amiibo.gameSeries)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Set
                    DetailRow(label: "Set", value: amiibo.amiiboSeries)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Type
                    DetailRow(label: "Type", value: amiibo.type)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Serial
                    DetailRow(label: "Serial", value: amiibo.head + amiibo.tail)
                }
                .padding(.horizontal, 60)
                
                // Action Buttons
                VStack(spacing: 0) {
                    // More from series button
                    Button(action: {
                        // Use DispatchQueue to ensure presentation happens after view update cycle
                        // This prevents conflicts when TabView is initializing or transitioning
                        DispatchQueue.main.async {
                            showingSeriesView = true
                        }
                        analyticsService.logEvent(AnalyticsService.AMIIBO_MORE, id: amiibo.head + amiibo.tail, name: "more_from_series")
                    }) {
                        Text("more from series")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 70)
                    
                    // Compatibility and usage button
                    Button(action: {
                        // Use DispatchQueue to ensure presentation happens after view update cycle
                        // This prevents conflicts when TabView is initializing or transitioning
                        DispatchQueue.main.async {
                            showingCompatibilityView = true
                        }
                        analyticsService.logEvent(AnalyticsService.AMIIBO_USAGE, id: amiibo.head + amiibo.tail, name: "compatibility_and_usage")
                    }) {
                        Text("compatibility and usage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 80)
                    
                    // Add to collection button
                    Button(action: {
                        // Haptic feedback
                        HapticManager.shared.lightImpact()
                        
                        if amiibo.isInCollection {
                            viewModel.removeFromCollection(amiibo)
                            analyticsService.logEvent(AnalyticsService.AMIIBO_ADD_COLLECTION, id: amiibo.head + amiibo.tail, name: "remove_from_collection")
                        } else {
                            viewModel.addToCollection(amiibo)
                            // Success haptic and animation
                            HapticManager.shared.success()
                            showingSuccessAnimation = true
                            analyticsService.logEvent(AnalyticsService.AMIIBO_ADD_COLLECTION, id: amiibo.head + amiibo.tail, name: "add_to_collection")
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: amiibo.isInCollection ? "minus.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(amiibo.isInCollection ? .green : .red)
                            Text(amiibo.isInCollection ? "remove from my collection" : "add to my collection")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(amiibo.isInCollection ? .green : .red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(amiibo.isInCollection ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(amiibo.isInCollection ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 85)
                }
                
                // Release Info
                if let release = amiibo.release {
                    ReleaseInfoView(release: release)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                }
                }
            }
            .padding(.bottom, 20)
        }
        .toolbar {
            // Only show toolbar if not in TabView (shouldHandleAds true means single item view)
            if shouldHandleAds {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        openAmazonLink(for: amiibo)
                        analyticsService.logEvent(AnalyticsService.AMIIBO_AMAZON, id: amiibo.head + amiibo.tail, name: amiibo.name)
                    }) {
                        Image(systemName: "cart")
                            .foregroundColor(.appRed)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Haptic feedback for wishlist action
                        HapticManager.shared.lightImpact()
                        let isAdding = !amiibo.isInWishlist
                        viewModel.toggleWishlist(amiibo)
                        let action = amiibo.isInWishlist ? "remove_from_wishlist" : "add_to_wishlist"
                        if isAdding {
                            // Success haptic when adding to wishlist
                            HapticManager.shared.success()
                        }
                        analyticsService.logEvent(AnalyticsService.AMIIBO_ADD_WISHLIST, id: amiibo.head + amiibo.tail, name: action)
                    }) {
                        Image(systemName: amiibo.isInWishlist ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.appRed)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .onTapGesture {
            // Dismiss keyboard when tapping anywhere on the details screen
            dismissKeyboard()
        }
        .onAppear {
            isDetailsPresented = true
            
            // Log screen view
            analyticsService.logScreenView("details_screen", screenClass: "AmiiboDetailsView")
            analyticsService.logEvent(AnalyticsService.AMIIBO_DETAILS_OPENED, id: amiibo.head + amiibo.tail, name: amiibo.name)
        }
        .onDisappear {
            isDetailsPresented = false
        }
        .onAppear {
            // Show interstitial ad (every 8th time) - only if ads not purchased and should handle ads
            if shouldHandleAds && !purchaseManager.isNoAdsPurchased {
                adMobService.showInterstitialAd {
                    // Ad dismissed or not shown
                }
            }
        }
        .overlay {
            // Success animation overlay - no message text to avoid overlap
            if showingSuccessAnimation {
                SuccessAnimationView(isShowing: $showingSuccessAnimation, message: "")
            }
        }
    }
    
    func openAmazonLink(for amiibo: Amiibo) {
        // Create Amazon search URL like Android implementation
        let amiiboName = amiibo.name.replacingOccurrences(of: "&", with: " ")
        let amiiboNameFiltered = amiiboName.replacingOccurrences(of: " ", with: "+")
        let amiiboType = amiibo.type
        let amiiboSeries = amiibo.gameSeries.replacingOccurrences(of: " ", with: "+")
        
        let amazonURL = "https://www.amazon.com/s?k=\(amiiboNameFiltered)+Amiibo+\(amiiboType)+\(amiiboSeries)&tag=amiibovault-20"
        
        if let url = URL(string: amazonURL) {
            UIApplication.shared.open(url)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 2)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .lineLimit(1)
                .padding(.leading, 5)
        }
        .padding(.vertical, 7)
    }
}

struct ReleaseInfoView: View {
    let release: Release
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Spacer()
            if let au = release.au, !au.isEmpty, au != "null" {
                ReleaseCard(date: au, flag: "au_flag")
            }
            
            if let eu = release.eu, !eu.isEmpty, eu != "null" {
                ReleaseCard(date: eu, flag: "eu_flag")
            }
            
            if let jp = release.jp, !jp.isEmpty, jp != "null" {
                ReleaseCard(date: jp, flag: "jp_flag")
            }
            
            if let na = release.na, !na.isEmpty, na != "null" {
                ReleaseCard(date: na, flag: "us_flag")
            }
            Spacer()
        }
    }
}

struct ReleaseCard: View {
    let date: String
    let flag: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: -7) {
            // Flag circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 35, height: 35)
                    .shadow(radius: 5)
                
                // Flag image
                Image(flag)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
            }
            
            // Date parts
            VStack(spacing: 0) {
                Text(dayAndMonth(from: date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .padding(.top, 12)
                
                Text(year(from: date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func dayAndMonth(from dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: dateString) {
            let dayMonthFormatter = DateFormatter()
            dayMonthFormatter.dateFormat = "dd MMM"
            dayMonthFormatter.locale = Locale(identifier: "en_US_POSIX")
            return dayMonthFormatter.string(from: date)
        }
        
        // Fallback: try to parse manually
        let components = dateString.components(separatedBy: "-")
        if components.count == 3 {
            // Assume components are in the order: year, month, day
            return "\(components[2]) \(components[1])"
        }
        return dateString
    }

    private func year(from dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: dateString) {
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            yearFormatter.locale = Locale(identifier: "en_US_POSIX")
            return yearFormatter.string(from: date)
        }
        
        // Fallback: try to parse manually
        let components = dateString.components(separatedBy: "-")
        if components.count == 3 {
            return components[0] // Assume the first component is the year
        }
        return ""
    }
}

