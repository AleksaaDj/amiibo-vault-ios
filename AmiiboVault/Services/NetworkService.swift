import Foundation
import Combine

// MARK: - Network Service
class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    private let baseURL = "https://amiiboapi.onrender.com/api/"
    private let rawgBaseURL = "https://api.rawg.io/api/"
    // TEMPORARY: Using LocalJsonService while server is down
    // TODO: When server is fixed, uncomment the API calls below and comment out LocalJsonService usage
    private let localJsonService = LocalJsonService.shared
    
    private init() {
        // Force initialization to test file access
        _ = LocalJsonService.shared
    }
    
    // MARK: - Amiibo API
    // TEMPORARY: Using local JSON files while server is down
    // TODO: When server is fixed, uncomment the API implementation below and comment out the localJsonService call
    func fetchAmiiboList() -> AnyPublisher<AmiiboListResponse, Error> {
        return localJsonService.fetchAmiiboList()
        // TODO: When server is fixed, uncomment the code below and comment out the line above
        /*
        guard let url = URL(string: "\(baseURL)amiibo/?") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: AmiiboListResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        */
    }
    
    // TEMPORARY: Using local JSON files while server is down
    // TODO: When server is fixed, uncomment the API implementation below and comment out the localJsonService call
    func fetchAmiiboConsoles(tail: String) -> AnyPublisher<Games, Error> {
        fflush(stdout)
        let result = localJsonService.fetchAmiiboConsoles(tail: tail)
        fflush(stdout)
        return result
        // TODO: When server is fixed, uncomment the code below and comment out the line above
        // NOTE: When uncommenting, you'll need to make Games Codable again or use manual JSON parsing
        /*
        guard let url = URL(string: "\(baseURL)amiibo/?&showusage&tail=\(tail)") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            // .decode(type: Games.self, decoder: JSONDecoder()) // Games is not Codable - use manual parsing instead
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
        */
    }
    
    // MARK: - Games API (RAWG)
    func fetchNintendoGames(apiKey: String, page: Int = 1, pageSize: Int = 40) -> AnyPublisher<GamesListResponse, Error> {
        // Platform IDs: 7=Nintendo Switch, 8=PC, 9=Xbox One, 10=Nintendo Switch, 11=Nintendo Wii U
        // Note: Switch 2 not yet in RAWG API
        let platforms = "7,8,9,10,11"
        let publishers = "nintendo"
        
        guard let url = URL(string: "\(rawgBaseURL)games?platforms=\(platforms)&publishers=\(publishers)&page_size=\(pageSize)&page=\(page)&key=\(apiKey)") else {
            return Fail(error: NetworkError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: GamesListResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func fetchAllNintendoGames(apiKey: String) -> AnyPublisher<[Game], Error> {
        var allGames: [Game] = []
        let pageSize = 40
        
        return Publishers.Sequence(sequence: 1...)
            .flatMap { page in
                self.fetchNintendoGames(apiKey: apiKey, page: page, pageSize: pageSize)
            }
            .handleEvents(receiveOutput: { response in
                allGames.append(contentsOf: response.results)
            })
            .filter { response in
                response.results.isEmpty || response.next == nil
            }
            .first()
            .map { _ in allGames }
            .eraseToAnyPublisher()
    }
}

// MARK: - Network Error
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
