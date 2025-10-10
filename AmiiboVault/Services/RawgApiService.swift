import Foundation

class RawgApiService {
    private let baseURL = "https://api.rawg.io/api"
    private var apiKey: String = ""
    
    init() {
        loadApiKey()
    }
    
    private func loadApiKey() {
        // RAWG API key for Nintendo games
        apiKey = "b50be92a7cc049729fe474281dee3aa8"
        
        // TODO: In production, this should be fetched from Firebase like the Android app
        // This should match the Android implementation where it fetches from Firebase
    }
    
    func fetchNintendoGames(completion: @escaping (Result<[Game], Error>) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ No API key provided")
            completion(.failure(RawgApiError.noApiKey))
            return
        }
        
        // Fetch all pages like Android implementation
        fetchAllPages(page: 1, allGames: [], completion: completion)
    }
    
    private func fetchAllPages(page: Int, allGames: [Game], completion: @escaping (Result<[Game], Error>) -> Void) {
        let urlString = "\(baseURL)/games?platforms=7,8,9,10,11&publishers=nintendo&page_size=40&page=\(page)&key=\(apiKey)"
        print("🌐 Fetching page \(page) from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            completion(.failure(RawgApiError.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Network error on page \(page): \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received on page \(page)")
                completion(.failure(RawgApiError.noData))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(GamesListResponse.self, from: data)
                print("✅ Successfully decoded \(response.results.count) games from page \(page)")
                
                // Filter games with rating > 0 (similar to Android)
                let filteredGames = response.results.filter { ($0.rating ?? 0.0) > 0.0 }
                print("🎮 Filtered to \(filteredGames.count) games with rating > 0 on page \(page)")
                
                let newAllGames = allGames + filteredGames
                
                // Check if there are more pages
                if response.next != nil && !response.results.isEmpty {
                    print("📄 More pages available, fetching page \(page + 1)...")
                    self.fetchAllPages(page: page + 1, allGames: newAllGames, completion: completion)
                } else {
                    print("✅ Finished fetching all pages. Total games: \(newAllGames.count)")
                    completion(.success(newAllGames))
                }
            } catch {
                print("❌ JSON decoding error on page \(page): \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchApiKeyFromFirebase(completion: @escaping (String?) -> Void) {
        // This would integrate with Firebase to get the RAWG API key
        // For now, return nil to indicate no key available
        completion(nil)
    }
}

enum RawgApiError: Error {
    case noApiKey
    case invalidURL
    case noData
    case decodingError
}
