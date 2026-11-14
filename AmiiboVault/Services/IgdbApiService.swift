import Foundation

enum IgdbConfig {
    static let twitchClientId = "c1wqno8vwjr5nzr211qfcz6m0o40dv"
    static let twitchClientSecret = "cr5wgvs1xwc4rhu2mzoylekb52lj9j"
    static let twitchTokenURL = "https://id.twitch.tv/oauth2/token"
    static let gamesURL = "https://api.igdb.com/v4/games"
    static let imageBase = "https://images.igdb.com/igdb/image/upload/"
    static let pageSize = 500
    static let throttleNs: UInt64 = 280_000_000
    static let gamesCacheVersion = 2
    static let gamesCacheVersionKey = "games_cache_version"
}

enum IgdbApiError: Error {
    case invalidURL
    case noData
    case httpError(Int)
    case decodingError
}

private struct TwitchTokenResponse: Decodable {
    let access_token: String
}

private struct IgdbGameDto: Decodable {
    let id: Int?
    let name: String?
    let cover: IgdbImageRef?
    let screenshots: [IgdbImageRef]?
    let genres: [IgdbNamedRef]?
    let platforms: [IgdbNamedRef]?
    let first_release_date: Int64?
    let aggregated_rating: Double?
    let rating: Double?
    let rating_count: Int?
}

private struct IgdbImageRef: Decodable {
    let id: Int?
    let image_id: String?

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let bareId = try? single.decode(Int.self) {
            id = bareId
            image_id = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        image_id = try container.decodeIfPresent(String.self, forKey: .image_id)
    }

    private enum CodingKeys: String, CodingKey {
        case id, image_id
    }
}

private struct IgdbNamedRef: Decodable {
    let id: Int?
    let name: String?
}

final class IgdbApiService {
    static let shared = IgdbApiService()

    private var cachedToken: String?
    private let localJson = LocalJsonService.shared
    private let fetchLock = NSLock()
    private var inFlightTask: Task<[Game], Error>?

    private init() {}

    /// Starts a cache refresh on launch so compatibility covers update without opening Games.
    func prefetchIfNeeded() {
        let stored = UserDefaults.standard.integer(forKey: IgdbConfig.gamesCacheVersionKey)
        let localGames = CoreDataService.shared.getAllGames()
        let hasLegacyRawg = localGames.contains { $0.backgroundImage?.contains("rawg.io") == true }
        if stored >= IgdbConfig.gamesCacheVersion && !localGames.isEmpty && !hasLegacyRawg { return }
        fetchGames { result in
            DispatchQueue.main.async {
                guard case .success(let games) = result, !games.isEmpty else { return }
                CoreDataService.shared.replaceAllGames(games)
                UserDefaults.standard.set(
                    IgdbConfig.gamesCacheVersion,
                    forKey: IgdbConfig.gamesCacheVersionKey
                )
            }
        }
    }

    func fetchGames(completion: @escaping (Result<[Game], Error>) -> Void) {
        Task {
            do {
                let games = try await fetchGames()
                completion(.success(games))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func fetchGames() async throws -> [Game] {
        fetchLock.lock()
        if let inFlightTask {
            fetchLock.unlock()
            return try await inFlightTask.value
        }
        let task = Task { try await self.performFetch() }
        inFlightTask = task
        fetchLock.unlock()
        defer {
            fetchLock.lock()
            inFlightTask = nil
            fetchLock.unlock()
        }
        return try await task.value
    }

    private func performFetch() async throws -> [Game] {
        let token = try await accessToken()
        var dtos: [IgdbGameDto] = []
        var offset = 0
        while true {
            try await throttle()
            let page = try await queryGames(token: token, body: nintendoQuery(offset: offset))
            dtos.append(contentsOf: page)
            if page.count < IgdbConfig.pageSize { break }
            offset += IgdbConfig.pageSize
        }
        // Failed/empty Nintendo dump must not replace a full local cache with extras only.
        if dtos.isEmpty { return [] }
        var games = dtos.compactMap { mapGame($0, nameOverride: nil) }
        var exact = Set(games.compactMap { $0.name?.lowercased() })
        var byNormalized: [String: Game] = [:]
        for game in games {
            if let name = game.name {
                byNormalized[normalize(name)] = game
            }
        }

        var extraSeq = 1_000_000_000
        let catalogNames = await uniqueCatalogGameNames()
        for catalogName in catalogNames {
            if exact.contains(catalogName.lowercased()) { continue }
            extraSeq += 1
            if let hit = byNormalized[normalize(catalogName)] {
                games.append(copyGame(hit, name: catalogName, extraId: extraSeq))
                exact.insert(catalogName.lowercased())
                continue
            }
            try await throttle()
            let results = (try? await queryGames(token: token, body: searchQuery(catalogName))) ?? []
            guard let match = pickMatch(catalogName, results),
                  let mapped = mapGame(match, nameOverride: catalogName, idOverride: extraSeq) else { continue }
            games.append(mapped)
            exact.insert(catalogName.lowercased())
        }
        return games
    }

    private func uniqueCatalogGameNames() async -> [String] {
        await withCheckedContinuation { continuation in
            localJson.uniqueAmiiboGameNames { names in
                continuation.resume(returning: names)
            }
        }
    }

    private func accessToken() async throws -> String {
        if let cachedToken { return cachedToken }
        guard let url = URL(string: IgdbConfig.twitchTokenURL) else {
            throw IgdbApiError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let form = [
            "client_id": IgdbConfig.twitchClientId,
            "client_secret": IgdbConfig.twitchClientSecret,
            "grant_type": "client_credentials"
        ]
        request.httpBody = form
            .map { key, value in
                let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(key)=\(encoded)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw IgdbApiError.httpError(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(TwitchTokenResponse.self, from: data)
        cachedToken = decoded.access_token
        return decoded.access_token
    }

    private func queryGames(token: String, body: String) async throws -> [IgdbGameDto] {
        guard let url = URL(string: IgdbConfig.gamesURL) else { throw IgdbApiError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(IgdbConfig.twitchClientId, forHTTPHeaderField: "Client-ID")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 401 {
            cachedToken = nil
            let retryToken = try await accessToken()
            request.setValue("Bearer \(retryToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
            if let retryHttp = retryResponse as? HTTPURLResponse, !(200...299).contains(retryHttp.statusCode) {
                throw IgdbApiError.httpError(retryHttp.statusCode)
            }
            return try JSONDecoder().decode([IgdbGameDto].self, from: retryData)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw IgdbApiError.httpError(http.statusCode)
        }
        return try JSONDecoder().decode([IgdbGameDto].self, from: data)
    }

    private func nintendoQuery(offset: Int) -> String {
        """
        fields name, cover.image_id, screenshots.image_id, genres.name, first_release_date, aggregated_rating, rating, rating_count, platforms.name;
        where platforms = (5,37,41,130,508)
          & involved_companies.company = 70
          & involved_companies.publisher = true;
        limit \(IgdbConfig.pageSize);
        offset \(offset);
        """
    }

    private func searchQuery(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "")
        return """
        search "\(escaped)";
        fields name, cover.image_id, screenshots.image_id, genres.name, first_release_date, aggregated_rating, rating, rating_count, platforms.name;
        limit 5;
        """
    }

    private func pickMatch(_ catalogName: String, _ results: [IgdbGameDto]) -> IgdbGameDto? {
        if let exact = results.first(where: { $0.name?.caseInsensitiveCompare(catalogName) == .orderedSame }) {
            return exact
        }
        let want = normalize(catalogName)
        guard !want.isEmpty else { return nil }
        return results.first(where: { normalize($0.name ?? "") == want })
            ?? results.first(where: {
                let got = normalize($0.name ?? "")
                return got.contains(want) || want.contains(got)
            })
    }

    private func mapGame(_ dto: IgdbGameDto, nameOverride: String?, idOverride: Int? = nil) -> Game? {
        let name = nameOverride ?? dto.name
        let coverId = dto.cover?.image_id
        let id = idOverride ?? dto.id ?? abs(name?.hashValue ?? 0)
        let genres = dto.genres?.enumerated().map { index, ref in
            Genre(id: ref.id ?? index, name: ref.name, slug: slug(ref.name ?? ""))
        }
        let platforms = dto.platforms?.enumerated().map { index, ref in
            Platform(id: ref.id ?? index, name: ref.name, slug: slug(ref.name ?? ""))
        }
        let shots = dto.screenshots?.compactMap { shot -> Screenshot? in
            guard let imageId = shot.image_id else { return nil }
            return Screenshot(id: shot.id, image: imageURL("t_screenshot_med", imageId))
        }
        return Game(
            id: id,
            name: name,
            backgroundImage: coverId.map { imageURL("t_cover_big", $0) },
            genres: genres,
            metacritic: dto.aggregated_rating.map { Int($0) },
            platforms: platforms,
            rating: dto.rating.map { ($0 / 20.0 * 10).rounded() / 10 },
            ratingsCount: dto.rating_count,
            released: formatRelease(dto.first_release_date),
            slug: name.map { slug($0) },
            shortScreenshots: shots
        )
    }

    private func copyGame(_ game: Game, name: String, extraId: Int) -> Game {
        return Game(
            id: extraId,
            name: name,
            backgroundImage: game.backgroundImage,
            genres: game.genres,
            metacritic: game.metacritic,
            platforms: game.platforms,
            rating: game.rating,
            ratingsCount: game.ratingsCount,
            released: game.released,
            slug: slug(name),
            shortScreenshots: game.shortScreenshots
        )
    }

    private func imageURL(_ size: String, _ imageId: String) -> String {
        "\(IgdbConfig.imageBase)\(size)/\(imageId).jpg"
    }

    private func slug(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func normalize(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private func formatRelease(_ unix: Int64?) -> String? {
        guard let unix else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return nil }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func throttle() async throws {
        try await Task.sleep(nanoseconds: IgdbConfig.throttleNs)
    }
}
