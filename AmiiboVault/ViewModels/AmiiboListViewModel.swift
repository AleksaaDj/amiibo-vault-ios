import Foundation
import Combine

// MARK: - Amiibo List ViewModel
class AmiiboListViewModel: ObservableObject {
    @Published var amiiboList: [Amiibo] = []
    @Published var filteredAmiiboList: [Amiibo] = []
    @Published var collectionAmiibos: [Amiibo] = []
    @Published var wishlistAmiibos: [Amiibo] = []
    @Published var featuredAmiibo: Amiibo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var isGridView = false
    @Published var sortType: String?
    @Published var selectedType: String?
    @Published var selectedSet: String?
    
    private let networkService = NetworkService.shared
    private let coreDataService = CoreDataService.shared
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasCheckedAPI = false
    private var hasInitialized = false
    private var lastRefreshTime: Date?
    
    init() {
        setupSearchPublisher()
        if !hasInitialized {
            hasInitialized = true
            loadAmiibos()
        }
    }
    
    // MARK: - Setup
    private func setupSearchPublisher() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.searchAmiibo(name: searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading (Database-First Approach - Android Pattern)
    func loadAmiibos() {
        
        // Always load from database first (like Android)
        loadFromDatabase()
        
        // Fetch featured Amiibo from Firebase (changes daily)
        fetchFeaturedAmiiboFromFirebase()
    }
    
    func loadAmiibosForScreenChange() {
        
        // Only refresh if we haven't loaded data yet or it's been a while
        if amiiboList.isEmpty || shouldRefreshData() {
            loadFromDatabaseOnly()
            lastRefreshTime = Date()
        } else {
        }
    }
    
    private func shouldRefreshData() -> Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        // Only refresh if it's been more than 5 minutes
        return Date().timeIntervalSince(lastRefresh) > 300
    }
    
    private func loadFromDatabase() {
        isLoading = true
        errorMessage = nil
        
        // Preserve current featured Amiibo before loading
        let currentFeatured = featuredAmiibo
        
        // Load from database with current sort and filters
        let localAmiibos = coreDataService.getFilteredAmiibos(
            searchQuery: searchText.isEmpty ? nil : searchText,
            typeFilter: selectedType,
            setFilter: selectedSet,
            sortType: sortType
        )
        
        // Update UI
        amiiboList = localAmiibos
        filteredAmiiboList = localAmiibos
        isLoading = false
        
        // Load collection and wishlist data
        loadCollectionAndWishlist()
        
        // Restore featured Amiibo if it was cleared
        if featuredAmiibo == nil && currentFeatured != nil {
            print("🔄 Restoring featured Amiibo: \(currentFeatured?.character ?? "Unknown")")
            featuredAmiibo = currentFeatured
        }
        
        // Debug: Check current featured Amiibo state
        if let featured = featuredAmiibo {
            print("✅ Featured Amiibo after load: \(featured.character)")
        } else {
            print("❌ No featured Amiibo after load")
        }
        
        print("✅ Loaded \(localAmiibos.count) Amiibos from database")
        
        // Only check API once when app starts, not on every screen change
        if !hasCheckedAPI {
            hasCheckedAPI = true
            checkAndUpdateFromAPI(localCount: localAmiibos.count)
        }
    }
    
    private func loadFromDatabaseOnly() {
        // Load from database without API check (for screen changes and sorting)
        let localAmiibos = coreDataService.getFilteredAmiibos(
            searchQuery: searchText.isEmpty ? nil : searchText,
            typeFilter: selectedType,
            setFilter: selectedSet,
            sortType: sortType
        )
        
        // Update UI
        amiiboList = localAmiibos
        filteredAmiiboList = localAmiibos
        
        // Load collection and wishlist data
        loadCollectionAndWishlist()
        
        lastRefreshTime = Date()
        print("✅ Refreshed \(localAmiibos.count) Amiibos from database")
    }
    
    private func loadFromAPI() {
        isLoading = true
        errorMessage = nil
        
        print("🌐 Fetching from API...")
        
        networkService.fetchAmiiboList()
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ Error fetching Amiibo data: \(error.localizedDescription)")
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    print("✅ Successfully fetched \(response.amiibo.count) Amiibos from API")
                    
                    // Debug: Check first few Amiibos for release data
                    for (index, amiibo) in response.amiibo.prefix(3).enumerated() {
                    }
                    
                    self?.saveToDatabase(response.amiibo)
                }
            )
            .store(in: &cancellables)
    }
    
    private func checkAndUpdateFromAPI(localCount: Int) {
        // Always fetch from API on first load to get complete data with release info
        print("🌐 Fetching from API to get complete data with release info...")
        loadFromAPI()
    }
    
    private func updateFromAPIIfNeeded(localCount: Int) {
        // Background update - only if remote has more data (like Android)
        networkService.fetchAmiiboList()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("❌ Background API check failed: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] response in
                    let remoteCount = response.amiibo.count
                    print("🔄 API check: Local=\(localCount), Remote=\(remoteCount)")
                    
                    if remoteCount > localCount {
                        print("📥 Updating database with \(remoteCount) Amiibos")
                        self?.saveToDatabase(response.amiibo)
                    } else {
                        print("✅ Local data is up to date")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func saveToDatabase(_ amiibos: [Amiibo]) {
        coreDataService.upsertAmiibos(amiibos)
        
        // Always refresh UI after saving to show updated data with release info
        let updatedAmiibos = coreDataService.getAllAmiibos(sortType: sortType)
        amiiboList = updatedAmiibos
        filteredAmiiboList = updatedAmiibos
        
        print("💾 Saved \(amiibos.count) Amiibos to database and refreshed UI")
    }
    
    // MARK: - Search and Filtering (Database-Based)
    func searchAmiibo(name: String) {
        searchAmiiboFiltered(name: name, type: selectedType, set: selectedSet)
    }
    
    func searchAmiiboFiltered(name: String, type: String?, set: String?) {
        // Use database-level filtering to avoid fetching all data
        var filteredResults = coreDataService.getFilteredAmiibos(
            searchQuery: name.isEmpty ? nil : name,
            typeFilter: type,
            setFilter: set,
            sortType: sortType
        )
        
        // Apply release date sorting if needed (since Core Data can't sort by parsed date strings)
        if let sortType = sortType, sortType.contains("Release Date") {
            filteredResults = sortAmiiboList(sortType: sortType, amiiboList: filteredResults)
        }
        
        // Update UI
        filteredAmiiboList = filteredResults
    }
    
    // MARK: - Filtering
    func applyFilters() {
        // Sorting is now handled at the database level
        // Just refresh the current search
        searchAmiibo(name: searchText)
    }
    
    func sortAmiiboList(sortType: String, amiiboList: [Amiibo]) -> [Amiibo] {
        switch sortType {
        case "Name A-Z":
            return amiiboList.sorted { $0.name < $1.name }
        case "Name Z-A":
            return amiiboList.sorted { $0.name > $1.name }
        case "Series A-Z":
            return amiiboList.sorted { $0.amiiboSeries < $1.amiiboSeries }
        case "Series Z-A":
            return amiiboList.sorted { $0.amiiboSeries > $1.amiiboSeries }
        case "Character A-Z":
            return amiiboList.sorted { $0.character < $1.character }
        case "Character Z-A":
            return amiiboList.sorted { $0.character > $1.character }
        case "Release Date (Newest)":
            return sortByReleaseDate(amiiboList: amiiboList, ascending: false)
        case "Release Date (Oldest)":
            return sortByReleaseDate(amiiboList: amiiboList, ascending: true)
        default:
            return amiiboList
        }
    }
    
    private func sortByReleaseDate(amiiboList: [Amiibo], ascending: Bool) -> [Amiibo] {
        // Create a cached date formatter for better performance
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Pre-parse all dates to avoid repeated parsing during sorting
        let amiiboWithDates = amiiboList.map { amiibo in
            let releaseDate: Date
            if let jp = amiibo.release?.jp, let parsedDate = formatter.date(from: jp) {
                releaseDate = parsedDate
            } else {
                releaseDate = Date.distantPast
            }
            return (amiibo: amiibo, date: releaseDate)
        }
        
        // Sort by the pre-parsed dates
        let sorted = amiiboWithDates.sorted { first, second in
            if ascending {
                return first.date < second.date
            } else {
                return first.date > second.date
            }
        }
        
        // Extract the sorted amiibos
        return sorted.map { $0.amiibo }
    }
    
    private func getReleaseDate(_ amiibo: Amiibo) -> Date {
        // Sort by JP release date specifically
        let release = amiibo.release
        
        if let jp = release?.jp, let jpDate = parseDate(jp) {
            return jpDate
        }
        
        // If no JP date, return a very old date so it appears at the end
        return Date.distantPast
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    // MARK: - Actions
    func toggleGridView() {
        isGridView.toggle()
    }
    
    func setSortType(_ sortType: String?) {
        self.sortType = sortType
        // Clear search text when sorting changes
        searchText = ""
        // Refresh data with new sorting (no API call)
        loadFromDatabaseOnly()
    }
    
    // MARK: - Filter Management
    func setTypeFilter(_ type: String?) {
        selectedType = type
        // Clear search text when filter changes
        searchText = ""
        // Apply filters with smooth transition
        searchAmiiboFiltered(name: searchText, type: selectedType, set: selectedSet)
    }
    
    func removeTypeFilter() {
        selectedType = nil
        // Clear search text when filter changes
        searchText = ""
        // Apply filters with smooth transition
        searchAmiiboFiltered(name: searchText, type: selectedType, set: selectedSet)
    }
    
    func setSetFilter(_ set: String?) {
        selectedSet = set
        // Clear search text when filter changes
        searchText = ""
        // Apply filters with smooth transition
        searchAmiiboFiltered(name: searchText, type: selectedType, set: selectedSet)
    }
    
    func removeSetFilter() {
        selectedSet = nil
        // Clear search text when filter changes
        searchText = ""
        // Apply filters with smooth transition
        searchAmiiboFiltered(name: searchText, type: selectedType, set: selectedSet)
    }
    
    
    
    // MARK: - Collection Management (Database-Based)
    func addToCollection(_ amiibo: Amiibo) {
        coreDataService.updateAmiiboCollectionStatus(tail: amiibo.tail, isInCollection: true)
        updateAmiiboInLists(amiibo, isInCollection: true)
    }
    
    func removeFromCollection(_ amiibo: Amiibo) {
        coreDataService.updateAmiiboCollectionStatus(tail: amiibo.tail, isInCollection: false)
        updateAmiiboInLists(amiibo, isInCollection: false)
    }
    
    func isInCollection(_ amiibo: Amiibo) -> Bool {
        return amiibo.isInCollection
    }
    
    // MARK: - Wishlist Management (Database-Based)
    func addToWishlist(_ amiibo: Amiibo) {
        coreDataService.updateAmiiboWishlistStatus(tail: amiibo.tail, isInWishlist: true)
        updateAmiiboInLists(amiibo, isInWishlist: true)
    }
    
    func removeFromWishlist(_ amiibo: Amiibo) {
        coreDataService.updateAmiiboWishlistStatus(tail: amiibo.tail, isInWishlist: false)
        updateAmiiboInLists(amiibo, isInWishlist: false)
    }
    
    func isInWishlist(_ amiibo: Amiibo) -> Bool {
        return amiibo.isInWishlist
    }
    
    func toggleWishlist(_ amiibo: Amiibo) {
        if isInWishlist(amiibo) {
            removeFromWishlist(amiibo)
        } else {
            addToWishlist(amiibo)
        }
    }
    
    // MARK: - Helper Methods
    private func updateAmiiboInLists(_ amiibo: Amiibo, isInCollection: Bool? = nil, isInWishlist: Bool? = nil) {
        // Update the specific amiibo in both lists without refreshing the entire list
        var updatedAmiibo = amiibo
        if let isInCollection = isInCollection {
            updatedAmiibo.isInCollection = isInCollection
        }
        if let isInWishlist = isInWishlist {
            updatedAmiibo.isInWishlist = isInWishlist
        }
        
        // Update in main list
        if let index = amiiboList.firstIndex(where: { $0.tail == amiibo.tail }) {
            amiiboList[index] = updatedAmiibo
        }
        
        // Update in filtered list
        if let index = filteredAmiiboList.firstIndex(where: { $0.tail == amiibo.tail }) {
            filteredAmiiboList[index] = updatedAmiibo
        }
        
        // Update collection and wishlist arrays
        refreshCollectionAndWishlist()
    }
    
    func refreshData() {
        // Manual refresh - reset API check flag and reload
        hasCheckedAPI = false
        loadFromDatabase()
    }
    
    private func refreshCurrentData() {
        // Refresh the current view with updated data from database
        if searchText.isEmpty {
            let allAmiibos = coreDataService.getAllAmiibos(sortType: sortType)
            amiiboList = allAmiibos
            filteredAmiiboList = allAmiibos
        } else {
            let searchResults = coreDataService.searchAmiibos(query: searchText, sortType: sortType)
            filteredAmiiboList = searchResults
        }
    }
    
    // MARK: - Collection and Wishlist Management
    func loadCollectionAndWishlist() {
        collectionAmiibos = amiiboList.filter { $0.isInCollection }
        wishlistAmiibos = amiiboList.filter { $0.isInWishlist }
    }
    
    func refreshCollectionAndWishlist() {
        loadCollectionAndWishlist()
    }
    
    // MARK: - Featured Amiibo Management
    func fetchFeaturedAmiiboFromFirebase() {
        print("🔥 Fetching featured Amiibo from Firebase...")
        
        // First, get current featured Amiibo from local database
        let currentFeaturedAmiibos = coreDataService.getFeaturedAmiibo()
        let currentFeaturedAmiibo = currentFeaturedAmiibos.first
        
        // Set it as featured Amiibo immediately (like Android)
        if let current = currentFeaturedAmiibo {
            featuredAmiibo = current
        }
        
        // Then fetch from Firebase
        firebaseService.fetchFeaturedAmiibo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let firebaseData):
                    print("✅ Featured Amiibo data received from Firebase: tail=\(firebaseData.tail)")
                    self?.updateFeaturedAmiiboFromFirebase(firebaseData, currentFeatured: currentFeaturedAmiibo)
                case .failure(let error):
                    print("❌ Failed to fetch featured Amiibo: \(error)")
                    // Keep using local database result
                }
            }
        }
    }
    
    private func updateFeaturedAmiiboFromFirebase(_ firebaseData: FirebaseFeaturedAmiibo, currentFeatured: Amiibo?) {
        // Search for the Amiibo in our local database by tail
        if let localAmiibo = amiiboList.first(where: { $0.tail == firebaseData.tail }) {
            print("🔍 Found Amiibo in local database: \(localAmiibo.character)")
            
            // Check if the Firebase Amiibo is different from current featured
            if firebaseData.tail != currentFeatured?.tail {
                print("🔄 Featured Amiibo changed from \(currentFeatured?.character ?? "none") to \(localAmiibo.character)")
                
                // Remove current featured status from all Amiibos
                if let current = currentFeatured {
                    coreDataService.setFeaturedAmiibo(amiibo: current, featured: false, color: 0)
                }
                
                // Set new featured Amiibo with a default color (you can customize this)
                let defaultColor = 0x6B6B6B // Default gray color (24-bit, fits in Int32)
                coreDataService.setFeaturedAmiibo(amiibo: localAmiibo, featured: true, color: defaultColor)
                
                // Create updated Amiibo with featured status
                let updatedAmiibo = Amiibo(
                    amiiboSeries: localAmiibo.amiiboSeries,
                    character: localAmiibo.character,
                    gameSeries: localAmiibo.gameSeries,
                    head: localAmiibo.head,
                    image: localAmiibo.image,
                    name: localAmiibo.name,
                    release: localAmiibo.release,
                    tail: localAmiibo.tail,
                    type: localAmiibo.type,
                    featured: true,
                    color: defaultColor,
                    isInCollection: localAmiibo.isInCollection,
                    isInWishlist: localAmiibo.isInWishlist
                )
                
                // Debug logging for release data
                if let release = localAmiibo.release {
                    print("🔍 Featured Amiibo release data: JP=\(release.jp ?? "nil"), NA=\(release.na ?? "nil"), EU=\(release.eu ?? "nil"), AU=\(release.au ?? "nil")")
                } else {
                    print("⚠️ Featured Amiibo has no release data")
                }
                
                // Update the published property
                featuredAmiibo = updatedAmiibo
                
                print("✅ Featured Amiibo updated: \(updatedAmiibo.character)")
            } else {
                print("ℹ️ Featured Amiibo unchanged: \(localAmiibo.character)")
            }
        } else {
            print("⚠️ Featured Amiibo not found in local database: tail=\(firebaseData.tail)")
            // Keep using current featured Amiibo
        }
    }
    
    func loadFeaturedAmiiboFromDatabase() {
        // Get featured Amiibo from database
        let featuredAmiibos = coreDataService.getFeaturedAmiibo()
        print("🔍 Loading featured Amiibo from database: \(featuredAmiibos.count) found")
        if let featured = featuredAmiibos.first {
            print("✅ Featured Amiibo: \(featured.character)")
        } else {
            print("❌ No featured Amiibo found in database")
        }
        featuredAmiibo = featuredAmiibos.first
    }
    
    func setFeaturedAmiibo(_ amiibo: Amiibo, color: Int) {
        coreDataService.setFeaturedAmiibo(amiibo: amiibo, featured: true, color: color)
        loadFeaturedAmiiboFromDatabase()
    }
    
    func removeFeaturedAmiibo(_ amiibo: Amiibo) {
        coreDataService.setFeaturedAmiibo(amiibo: amiibo, featured: false, color: 0)
        loadFeaturedAmiiboFromDatabase()
    }
}
