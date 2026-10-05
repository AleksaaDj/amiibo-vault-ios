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
    @Published var showErrorAlert = false
    @Published var errorAlertMessage = ""
    @Published var searchText = ""
    @Published var isGridView = false
    @Published var sortType: String?
    @Published var selectedType: String?
    @Published var selectedSet: String?
    @Published var collectionCatalogFilter: CollectionCatalogFilter = .all
    
    private let networkService = NetworkService.shared
    private let coreDataService = CoreDataService.shared
    private let firebaseService = FirebaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false
    private var lastRefreshTime: Date?
    /// Avoid spamming featured-amiibo Firebase on every `loadFromDatabase` (can run often from SwiftUI).
    private var hasRequestedFeaturedThisSession = false
    
    init() {
        print("========== VIEWMODEL INIT ==========")
        print("🔵 AmiiboListViewModel: init() called")
        setupSearchPublisher()
        if !hasInitialized {
            hasInitialized = true
            print("🔵 AmiiboListViewModel: Calling loadAmiibos() from init")
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
        NSLog("🔵 AmiiboListViewModel: loadAmiibos() called")
        print("🔵 AmiiboListViewModel: loadAmiibos() called")
        
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
        // Load from database instantly - no loading state needed
        let currentFeatured = featuredAmiibo
        
        // Load from database with current sort and filters
        let localAmiibos = coreDataService.getFilteredAmiibos(
            searchQuery: searchText.isEmpty ? nil : searchText,
            typeFilter: selectedType,
            setFilter: selectedSet,
            sortType: sortType
        )
        
        print("========== DATABASE CHECK ==========")
        print("🔵 AmiiboListViewModel: Found \(localAmiibos.count) items in database")
        
        amiiboList = localAmiibos
        filteredAmiiboList = applyCollectionCatalogFilter(localAmiibos)
        if let sortType, sortType.contains("Release") {
            filteredAmiiboList = AmiiboSortHelper.sort(filteredAmiiboList, by: sortType)
        }
        
        // Load collection and wishlist data
        loadCollectionAndWishlist()
        
        // Restore featured Amiibo if it was cleared
        if featuredAmiibo == nil && currentFeatured != nil {
            featuredAmiibo = currentFeatured
        }
        
        // Catalog sync when stale (nil lastRefresh or > 5 min) — picks up Firebase name / count changes after version bump.
        if shouldRefreshData() {
            print("🔵 AmiiboListViewModel: Calling syncWithAPIInBackground with count: \(localAmiibos.count)")
            syncWithAPIInBackground(localCount: localAmiibos.count)
        }
        
        if !hasRequestedFeaturedThisSession {
            hasRequestedFeaturedThisSession = true
            if localAmiibos.count > 0 {
                loadFeaturedAmiiboFromAPI()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.loadFeaturedAmiiboFromAPI()
                }
            }
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
        
        amiiboList = localAmiibos
        filteredAmiiboList = applyCollectionCatalogFilter(localAmiibos)
        if let sortType, sortType.contains("Release") {
            filteredAmiiboList = AmiiboSortHelper.sort(filteredAmiiboList, by: sortType)
        }
        
        loadCollectionAndWishlist()
        lastRefreshTime = Date()
    }
    
    private func loadFromAPI() {
        isLoading = true
        errorMessage = nil
        
        NSLog("🔵 AmiiboListViewModel: loadFromAPI() called - about to fetch amiibo list")
        print("🔵 AmiiboListViewModel: loadFromAPI() called - about to fetch amiibo list")
        
        networkService.fetchAmiiboList()
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.isLoading = false
                        if case .failure(let error) = completion {
                            var errorDesc = error.localizedDescription
                            
                            if let detailedError = error as? LocalizedError {
                                errorDesc = detailedError.errorDescription ?? errorDesc
                            }
                            
                            if let nsError = error as NSError? {
                                errorDesc += "\n\nDomain: \(nsError.domain)\nCode: \(nsError.code)"
                                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                                    errorDesc += "\nUnderlying: \(underlyingError.localizedDescription)"
                                }
                            }
                            
                            NSLog("❌ AmiiboListViewModel: loadFromAPI() failed: \(errorDesc)")
                            print("❌ AmiiboListViewModel: loadFromAPI() failed: \(errorDesc)")
                            self.errorMessage = errorDesc
                            self.errorAlertMessage = "Failed to load Amiibo data:\n\n\(errorDesc)\n\nError type: \(type(of: error))"
                            self.showErrorAlert = true
                            print("🔵 Setting showErrorAlert = true, message: \(self.errorAlertMessage)")
                        } else {
                            NSLog("✅ AmiiboListViewModel: loadFromAPI() succeeded")
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    // Publisher completes on a background queue (e.g. LocalJsonService catalog queue);
                    // Core Data + @Published UI must run on the main queue.
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        for (_, _) in response.amiibo.prefix(3).enumerated() {}
                        self.saveToDatabase(response.amiibo)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.loadFeaturedAmiiboFromAPI()
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadFeaturedAmiiboFromAPI() {
        // Load featured Amiibo from Firebase on every start (changes frequently)
        firebaseService.fetchFeaturedAmiibo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let firebaseData):
                    // Search for the Amiibo in our local database by tail
                    if let localAmiibo = self?.amiiboList.first(where: { $0.tail == firebaseData.tail }) {
                        // Set as featured in database and update UI
                        self?.coreDataService.setFeaturedAmiibo(amiibo: localAmiibo, featured: true, color: 0)
                        self?.featuredAmiibo = localAmiibo
                    } else {
                        // Fallback to database if not found locally
                        self?.loadFeaturedAmiiboFromDatabase()
                    }
                case .failure(_):
                    // Fallback to database if Firebase fails
                    self?.loadFeaturedAmiiboFromDatabase()
                }
            }
        }
    }
    
    private func syncWithAPIInBackground(localCount: Int) {
        // Background sync - doesn't block UI
        NSLog("🔵 AmiiboListViewModel: syncWithAPIInBackground() called with localCount: \(localCount)")
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            // Only check API if we have local data
            guard localCount > 0 else {
                // No local data, load from API normally
                print("========== NO LOCAL DATA - CALLING API ==========")
                print("🔵 AmiiboListViewModel: No local data, calling loadFromAPI()")
                DispatchQueue.main.async {
                    self.loadFromAPI()
                }
                return
            }
            
            // Caller (`loadFromDatabase`) already gated with `shouldRefreshData()`.
            NSLog("🔵 AmiiboListViewModel: Calling networkService.fetchAmiiboList() in background")
            self.networkService.fetchAmiiboList()
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            // API failed, but we have local data so continue silently
                            NSLog("❌ AmiiboListViewModel: API failed in syncWithAPIInBackground: \(error.localizedDescription)")
                            print("❌ AmiiboListViewModel: API failed in syncWithAPIInBackground: \(error.localizedDescription)")
                        } else {
                            NSLog("✅ AmiiboListViewModel: API succeeded in syncWithAPIInBackground")
                        }
                    },
                    receiveValue: { response in
                        // Always merge catalog into Core Data when fetch succeeds (same count as local still
                        // means names/images/series may have changed on Firebase). upsert preserves collection/wishlist.
                        DispatchQueue.main.async {
                            self.updateDatabaseWithAPIResponse(response)
                        }
                    }
                )
                .store(in: &self.cancellables)
        }
    }
    
    private func updateDatabaseWithAPIResponse(_ response: AmiiboListResponse) {
        // Update database with new API data
        coreDataService.upsertAmiibos(response.amiibo)
        
        // Refresh UI with updated data
        let updatedAmiibos = coreDataService.getFilteredAmiibos(
            searchQuery: searchText.isEmpty ? nil : searchText,
            typeFilter: selectedType,
            setFilter: selectedSet,
            sortType: sortType
        )
        
        amiiboList = updatedAmiibos
        applyCurrentFilters()
        
        // Update collection and wishlist
        loadCollectionAndWishlist()
        
        lastRefreshTime = Date()
        
        // Load featured Amiibo if we don't have one yet
        if featuredAmiibo == nil {
            loadFeaturedAmiiboFromAPI()
        }
    }
    
    private func saveToDatabase(_ amiibos: [Amiibo]) {
        coreDataService.upsertAmiibos(amiibos)
        
        // Always refresh UI after saving to show updated data with release info
        let updatedAmiibos = coreDataService.getAllAmiibos(sortType: sortType)
        amiiboList = updatedAmiibos
        filteredAmiiboList = updatedAmiibos
        
        lastRefreshTime = Date()
        
        // Load featured Amiibo if we don't have one yet
        if featuredAmiibo == nil {
            loadFeaturedAmiiboFromAPI()
        }
    }
    
    // MARK: - Search and Filtering (Database-Based)
    func searchAmiibo(name: String) {
        searchAmiiboFiltered(name: name, type: selectedType, set: selectedSet)
    }
    
    func applyCurrentFilters() {
        searchAmiiboFiltered(name: searchText, type: selectedType, set: selectedSet)
    }

    func searchAmiiboFiltered(name: String, type: String?, set: String?) {
        // Use database-level filtering to avoid fetching all data
        var filteredResults = coreDataService.getFilteredAmiibos(
            searchQuery: name.isEmpty ? nil : name,
            typeFilter: type,
            setFilter: set,
            sortType: sortType
        )
        
        filteredResults = applyCollectionCatalogFilter(filteredResults)

        if let sortType = sortType, sortType.contains("Release") {
            filteredResults = AmiiboSortHelper.sort(filteredResults, by: sortType)
        }
        
        filteredAmiiboList = filteredResults
    }

    func applyCollectionCatalogFilter(_ list: [Amiibo]) -> [Amiibo] {
        switch collectionCatalogFilter {
        case .all:
            return list
        case .notCollected:
            return list.filter { !$0.isInCollection }
        case .inCollectionOnly:
            return list.filter { $0.isInCollection }
        }
    }

    func clearAllFilters() {
        selectedType = nil
        selectedSet = nil
        collectionCatalogFilter = .all
        searchText = ""
        searchAmiiboFiltered(name: "", type: nil, set: nil)
    }

    var activeFilterCount: Int {
        var count = 0
        if collectionCatalogFilter != .all { count += 1 }
        if selectedType != nil { count += 1 }
        if selectedSet != nil { count += 1 }
        return count
    }
    
    // MARK: - Actions
    func toggleGridView() {
        isGridView.toggle()
    }
    
    func setSortType(_ sortType: String?) {
        self.sortType = sortType
        searchText = ""
        loadFromDatabaseOnly()
    }
    // MARK: - Collection Management (Database-Based)
    func addToCollection(_ amiibo: Amiibo) {
        coreDataService.updateAmiiboCollectionStatus(tail: amiibo.tail, isInCollection: true)
        updateAmiiboInLists(amiibo, isInCollection: true)
    }
    
    func removeFromCollection(_ amiibo: Amiibo) {
        coreDataService.updateAmiiboCollectionStatus(tail: amiibo.tail, isInCollection: false)
        updateAmiiboInLists(amiibo, isInCollection: false)
        if collectionCatalogFilter != .all {
            applyCurrentFilters()
        }
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
        
        // Reassign arrays so @Published fires without a full DB refetch (preserves details animations).
        if let index = amiiboList.firstIndex(where: { $0.tail == amiibo.tail }) {
            var list = amiiboList
            list[index] = updatedAmiibo
            amiiboList = list
        }

        if let index = filteredAmiiboList.firstIndex(where: { $0.tail == amiibo.tail }) {
            var list = filteredAmiiboList
            list[index] = updatedAmiibo
            filteredAmiiboList = list
        }
        
        // Update collection and wishlist arrays
        refreshCollectionAndWishlist()
    }
    
    func refreshData() {
        // Force next `loadFromDatabase` to run catalog sync (Firebase name / version changes).
        lastRefreshTime = nil
        loadFromDatabase()
    }
    
    // MARK: - Collection and Wishlist Management
    func loadCollectionAndWishlist() {
        // Get collection and wishlist directly from database (unfiltered by main screen)
        collectionAmiibos = coreDataService.getCollectionAmiibos()
        wishlistAmiibos = coreDataService.getWishlistAmiibos()
    }
    
    func refreshCollectionAndWishlist() {
        loadCollectionAndWishlist()
    }
    
    // MARK: - Featured Amiibo Management
    func fetchFeaturedAmiiboFromFirebase() {
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
                    self?.updateFeaturedAmiiboFromFirebase(firebaseData, currentFeatured: currentFeaturedAmiibo)
                case .failure(_):
                    // Keep using local database result
                    break
                }
            }
        }
    }
    
    private func updateFeaturedAmiiboFromFirebase(_ firebaseData: FirebaseFeaturedAmiibo, currentFeatured: Amiibo?) {
        guard let localAmiibo = amiiboList.first(where: { $0.tail == firebaseData.tail }) else { return }

        let firebaseImage = firebaseData.image.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayImage = firebaseImage.isEmpty ? localAmiibo.image : firebaseImage
        let defaultColor = 0x6B6B6B
        let tailChanged = firebaseData.tail != currentFeatured?.tail
        let imageChanged = currentFeatured?.image != displayImage

        if tailChanged {
            if let current = currentFeatured {
                coreDataService.setFeaturedAmiibo(amiibo: current, featured: false, color: 0)
            }
            coreDataService.setFeaturedAmiibo(amiibo: localAmiibo, featured: true, color: defaultColor)
        } else if imageChanged, let current = currentFeatured {
            coreDataService.setFeaturedAmiibo(amiibo: current, featured: true, color: defaultColor)
        }

        featuredAmiibo = Amiibo(
            amiiboSeries: localAmiibo.amiiboSeries,
            character: localAmiibo.character,
            gameSeries: localAmiibo.gameSeries,
            head: localAmiibo.head,
            image: displayImage,
            name: localAmiibo.name,
            release: localAmiibo.release,
            tail: localAmiibo.tail,
            type: localAmiibo.type,
            featured: true,
            color: defaultColor,
            isInCollection: localAmiibo.isInCollection,
            isInWishlist: localAmiibo.isInWishlist
        )
    }
    
    func loadFeaturedAmiiboFromDatabase() {
        // Preserve current featured Amiibo if it exists
        let currentFeatured = featuredAmiibo
        
        // Get featured Amiibo from database
        let featuredAmiibos = coreDataService.getFeaturedAmiibo()
        
        if let featured = featuredAmiibos.first {
            featuredAmiibo = featured
        } else {
            // Only clear if we don't have a current featured amiibo
            if currentFeatured == nil {
                featuredAmiibo = nil
            }
        }
    }
    
    func setFeaturedAmiibo(_ amiibo: Amiibo, color: Int) {
        coreDataService.setFeaturedAmiibo(amiibo: amiibo, featured: true, color: color)
        loadFeaturedAmiiboFromDatabase()
    }
    
    func removeFeaturedAmiibo(_ amiibo: Amiibo) {
        coreDataService.setFeaturedAmiibo(amiibo: amiibo, featured: false, color: 0)
        loadFeaturedAmiiboFromDatabase()
    }
    
    // MARK: - Collection Image Generation
    func createAndDownloadCompositeImage(isWishlist: Bool = false, completion: @escaping (Bool) -> Void) {
        
        let amiiboList = isWishlist ? wishlistAmiibos : collectionAmiibos
        if amiiboList.isEmpty {
            completion(false)
            return
        }
        
        let compositeHelper = CompositeImageHelper()
        compositeHelper.createAndSaveCompositeImage(amiiboList: amiiboList) { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
