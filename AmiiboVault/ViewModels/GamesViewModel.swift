import Foundation
import Combine

class GamesViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var filteredGames: [Game] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var selectedSortType: String?
    @Published var selectedGenre: String?
    
    private let coreDataService = CoreDataService.shared
    private let rawgApiService = RawgApiService()
    private var cancellables = Set<AnyCancellable>()
    
    // Available sort options
    let sortOptions = [
        "Name (A-Z)",
        "Name (Z-A)",
        "Rating (High to Low)",
        "Rating (Low to High)",
        "Release Date (Newest)",
        "Release Date (Oldest)"
    ]
    
    // Available genres (predefined list matching Android)
    let availableGenres = [
        "Action",
        "Adventure", 
        "RPG",
        "Strategy",
        "Shooter",
        "Casual",
        "Simulation",
        "Puzzle",
        "Arcade",
        "Platformer",
        "Massively Multiplayer",
        "Racing",
        "Sports",
        "Fighting",
        "Family",
        "Board Games",
        "Card",
        "Educational"
    ]
    
    init() {
        loadGames()
        setupSearchPublisher()
    }
    
    private func setupSearchPublisher() {
        Publishers.CombineLatest3(
            $searchText,
            $selectedSortType,
            $selectedGenre
        )
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] searchText, sortType, genre in
            self?.performSearch(searchText: searchText, sortType: sortType, genre: genre)
        }
        .store(in: &cancellables)
    }
    
    func loadGames() {
        isLoading = true
        errorMessage = nil
        
        // First check local database
        let localGames = coreDataService.getAllGames()
        
        if localGames.isEmpty {
            // No local data, fetch from API
            fetchGamesFromAPI()
        } else {
            // Check if games have valid images (like Android - images should always be present)
            let gamesWithMissingImages = localGames.filter { game in
                guard let imageUrl = game.backgroundImage, !imageUrl.isEmpty else { return true }
                return false
            }
            
            // If any games are missing images, re-fetch from API to ensure we have complete data
            if !gamesWithMissingImages.isEmpty {
                // Some games are missing images, re-fetch to get complete data
                fetchGamesFromAPI()
            } else {
                // Use local data and sort by name
                let sortedGames = localGames.sorted { ($0.name ?? "") < ($1.name ?? "") }
                games = sortedGames
                filteredGames = sortedGames
                
                // Preload first few images before showing the list
                preloadGameImages(sortedGames.prefix(10))
            }
        }
    }
    
    private func preloadGameImages(_ games: ArraySlice<Game>) {
        let group = DispatchGroup()
        
        for game in games {
            guard let imageUrlString = game.backgroundImage,
                  let imageUrl = URL(string: imageUrlString) else { continue }
            
            group.enter()
            URLSession.shared.dataTask(with: imageUrl) { _, _, _ in
                group.leave()
            }.resume()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func fetchGamesFromAPI() {
        rawgApiService.fetchNintendoGames { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedGames):
                    // Sort by name by default
                    let sortedGames = fetchedGames.sorted { ($0.name ?? "") < ($1.name ?? "") }
                    self?.games = sortedGames
                    self?.filteredGames = sortedGames
                    self?.coreDataService.saveGames(sortedGames)
                    self?.isLoading = false
                case .failure(let error):
                    self?.errorMessage = "Failed to load games: \(error.localizedDescription)"
                    self?.isLoading = false
                }
            }
        }
    }
    
    
    private func performSearch(searchText: String, sortType: String?, genre: String?) {
        var results: [Game]
        
        if !searchText.isEmpty && !(genre?.isEmpty ?? true) {
            // Both search and genre filter
            results = coreDataService.searchGamesFiltered(
                query: searchText,
                genre: genre ?? "",
                sortType: sortType
            )
        } else if !searchText.isEmpty {
            // Only search
            results = coreDataService.searchGames(query: searchText, sortType: sortType)
        } else if !(genre?.isEmpty ?? true) {
            // Only genre filter
            results = coreDataService.searchGamesByGenre(genre: genre ?? "", sortType: sortType)
        } else {
            // No filters, get all games
            results = coreDataService.getAllGames(sortType: sortType)
        }
        
        // Apply client-side sorting for release dates (similar to AmiiboListViewModel)
        if let sortType = sortType, sortType.contains("Release Date") {
            results = sortGamesByReleaseDate(games: results, ascending: sortType.contains("Oldest"))
        }
        
        filteredGames = results
    }
    
    func searchGames(query: String) {
        searchText = query
    }
    
    func searchGamesFiltered(query: String, genre: String) {
        searchText = query
        selectedGenre = genre.isEmpty ? nil : genre
    }
    
    func selectSortType(_ sortType: String) {
        selectedSortType = sortType
        searchText = "" // Clear search when sorting
    }
    
    func removeSortType() {
        selectedSortType = nil
    }
    
    func selectGenre(_ genre: String) {
        selectedGenre = genre
        searchText = "" // Clear search when filtering
    }
    
    func removeGenre() {
        selectedGenre = nil
    }
    
    
    private func sortGamesByReleaseDate(games: [Game], ascending: Bool) -> [Game] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return games.sorted { game1, game2 in
            let date1 = game1.released.flatMap { formatter.date(from: $0) } ?? Date.distantPast
            let date2 = game2.released.flatMap { formatter.date(from: $0) } ?? Date.distantPast
            
            return ascending ? date1 < date2 : date1 > date2
        }
    }
}
