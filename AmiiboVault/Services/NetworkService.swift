import Foundation
import Combine

// MARK: - Network Service
class NetworkService: ObservableObject {
    static let shared = NetworkService()
    
    private let baseURL = "https://amiiboapi.onrender.com/api/"
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
