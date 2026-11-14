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
    @Published var selectedConsole: String?
    
    private let coreDataService = CoreDataService.shared
    private let igdbApiService = IgdbApiService.shared
    private var cancellables = Set<AnyCancellable>()
    private var isFetchingIgdb = false
    
    let sortOptions = [
        "Name (A-Z)",
        "Name (Z-A)",
        "Rating (High to Low)",
        "Rating (Low to High)",
        "Release Date (Newest)",
        "Release Date (Oldest)"
    ]
    
    let availableGenreOptions = GameDisplay.genreOptions
    let availableConsoles = GameDisplay.consoles
    
    init() {
        loadGames()
        setupSearchPublisher()
    }
    
    private func setupSearchPublisher() {
        Publishers.CombineLatest4(
            $searchText,
            $selectedSortType,
            $selectedGenre,
            $selectedConsole
        )
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] searchText, sortType, genre, console in
            self?.performSearch(searchText: searchText, sortType: sortType, genre: genre, console: console)
        }
        .store(in: &cancellables)
    }
    
    func loadGames() {
        errorMessage = nil
        let localGames = coreDataService.getAllGames()
        if !localGames.isEmpty {
            let sortedGames = localGames.sorted { ($0.name ?? "") < ($1.name ?? "") }
            games = sortedGames
            applyCurrentFilters()
            isLoading = false
        } else {
            isLoading = true
        }

        let storedVersion = UserDefaults.standard.integer(forKey: IgdbConfig.gamesCacheVersionKey)
        let hasLegacyRawg = localGames.contains { $0.backgroundImage?.contains("rawg.io") == true }
        let needsFetch = storedVersion < IgdbConfig.gamesCacheVersion || localGames.isEmpty || hasLegacyRawg
        if needsFetch {
            fetchGamesFromAPI()
        }
    }
    
    private func fetchGamesFromAPI() {
        guard !isFetchingIgdb else { return }
        isFetchingIgdb = true
        igdbApiService.fetchGames { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isFetchingIgdb = false
                switch result {
                case .success(let fetchedGames):
                    guard !fetchedGames.isEmpty else {
                        self.isLoading = false
                        return
                    }
                    self.coreDataService.replaceAllGames(fetchedGames)
                    UserDefaults.standard.set(
                        IgdbConfig.gamesCacheVersion,
                        forKey: IgdbConfig.gamesCacheVersionKey
                    )
                    let sortedGames = fetchedGames.sorted { ($0.name ?? "") < ($1.name ?? "") }
                    self.games = sortedGames
                    self.applyCurrentFilters()
                    self.isLoading = false
                case .failure:
                    self.isLoading = false
                    if self.games.isEmpty {
                        self.errorMessage = "Failed to load games"
                    }
                }
            }
        }
    }
    
    private func applyCurrentFilters() {
        performSearch(
            searchText: searchText,
            sortType: selectedSortType,
            genre: selectedGenre,
            console: selectedConsole
        )
    }
    
    private func performSearch(searchText: String, sortType: String?, genre: String?, console: String?) {
        var results = games.isEmpty ? coreDataService.getAllGames(sortType: sortType) : games
        
        if !searchText.isEmpty {
            results = results.filter { game in
                game.name?.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        if let genre, !genre.isEmpty {
            results = results.filter { GameDisplay.matchesGenre($0, selected: genre) }
        }
        if let console, !console.isEmpty {
            results = results.filter { GameDisplay.matchesConsole($0, selected: console) }
        }
        
        results = sortGames(results, sortType: sortType)
        
        if results.isEmpty && !filteredGames.isEmpty &&
            (isFetchingIgdb || (searchText.isEmpty && genre == nil && console == nil)) {
            return
        }
        
        filteredGames = results
    }
    
    private func sortGames(_ games: [Game], sortType: String?) -> [Game] {
        switch sortType {
        case "Name (Z-A)":
            return games.sorted { ($0.name ?? "") > ($1.name ?? "") }
        case "Rating (High to Low)":
            return games.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case "Rating (Low to High)":
            return games.sorted { ($0.rating ?? 0) < ($1.rating ?? 0) }
        case "Release Date (Newest)":
            return sortGamesByReleaseDate(games: games, ascending: false)
        case "Release Date (Oldest)":
            return sortGamesByReleaseDate(games: games, ascending: true)
        default:
            return games.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
    }
    
    func selectSortType(_ sortType: String) {
        selectedSortType = sortType
        searchText = ""
    }
    
    func removeSortType() {
        selectedSortType = nil
    }
    
    func selectGenre(_ genre: String) {
        selectedGenre = genre
        searchText = ""
    }
    
    func removeGenre() {
        selectedGenre = nil
    }
    
    func selectConsole(_ console: String) {
        selectedConsole = console
        searchText = ""
    }
    
    func removeConsole() {
        selectedConsole = nil
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
