import Foundation

class RawgApiService {
    private let baseURL = "https://api.rawg.io/api"
    private let firebaseService = FirebaseService.shared

    func fetchNintendoGames(completion: @escaping (Result<[Game], Error>) -> Void) {
        firebaseService.fetchRawgApiKey { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let apiKey):
                self.fetchAllPages(apiKey: apiKey, page: 1, allGames: [], completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func fetchAllPages(
        apiKey: String,
        page: Int,
        allGames: [Game],
        completion: @escaping (Result<[Game], Error>) -> Void
    ) {
        let urlString =
            "\(baseURL)/games?platforms=7,8,9,10,11&publishers=nintendo&page_size=40&page=\(page)&key=\(apiKey)"

        guard let url = URL(string: urlString) else {
            completion(.failure(RawgApiError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("RAWG HTTP \(http.statusCode): \(body.prefix(200))")
                completion(.failure(RawgApiError.httpError(http.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(RawgApiError.noData))
                return
            }

            do {
                let response = try JSONDecoder().decode(GamesListResponse.self, from: data)
                let filteredGames = response.results.filter { ($0.rating ?? 0.0) > 0.0 }
                let newAllGames = allGames + filteredGames

                if response.next != nil, !response.results.isEmpty {
                    self.fetchAllPages(
                        apiKey: apiKey,
                        page: page + 1,
                        allGames: newAllGames,
                        completion: completion
                    )
                } else {
                    completion(.success(newAllGames))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

enum RawgApiError: Error {
    case invalidURL
    case noData
    case decodingError
    case httpError(Int)
}
