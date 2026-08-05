import Foundation
import Combine

// MARK: - Local JSON Service
// Loads catalog from Firebase (`catalog` node) when available, else bundled JSON (same strategy as Android).
class LocalJsonService {
    static let shared = LocalJsonService()

    private var cachedAmiiboList: AmiiboListResponse?
    private var cachedGamesDataRaw: [String: [String: Any]]?

    /// Serializes catalog load so concurrent `fetchAmiiboList` / `fetchAmiiboConsoles` do not double-fetch Firebase.
    private let catalogQueue = DispatchQueue(label: "com.softwavegames.amiibovault.catalog")

    private init() {}

    // MARK: - Bundle URL (amiibo / games_info)

    private func bundleURL(forResource name: String, extension ext: String) -> URL? {
        var url = Bundle.main.url(forResource: name, withExtension: ext)
        if url == nil, let resourcePath = Bundle.main.resourcePath {
            let directPath = "\(resourcePath)/\(name).\(ext)"
            if FileManager.default.fileExists(atPath: directPath) {
                url = URL(fileURLWithPath: directPath)
            }
        }
        if url == nil, let resourcePath = Bundle.main.resourcePath {
            let assetsPath = "\(resourcePath)/Assets/\(name).\(ext)"
            if FileManager.default.fileExists(atPath: assetsPath) {
                url = URL(fileURLWithPath: assetsPath)
            }
        }
        return url
    }

    /// Firebase + disk cache, or bundled `amiibo.json` + `games_info.json`.
    /// Always runs `tryLoadCatalog` (version check + disk/network) — do not skip when memory cache is filled,
    /// or `catalog/version` bumps never refresh until app reinstall (matches fixing stale `Just(cached)` on fetch).
    private func ensureCatalogOrBundled(completion: @escaping (Error?) -> Void) {
        catalogQueue.async {
            let sem = DispatchSemaphore(value: 0)
            var err: Error?
            AmiiboCatalogSync.shared.tryLoadCatalog { amiibo, games in
                if let a = amiibo, let g = games {
                    self.cachedAmiiboList = a
                    self.cachedGamesDataRaw = g
                } else {
                    do {
                        try self.loadBundledCatalog()
                    } catch {
                        err = error
                    }
                }
                sem.signal()
            }
            sem.wait()
            completion(err)
        }
    }

    private func loadBundledCatalog() throws {
        guard let amiiboURL = bundleURL(forResource: "amiibo", extension: "json") else {
            throw NetworkError.invalidURL
        }
        let amiiboData = try Data(contentsOf: amiiboURL)
        let amiiboObject = try JSONSerialization.jsonObject(with: amiiboData, options: [.allowFragments])
        guard let jsonDict = amiiboObject as? [String: Any],
              let amiiboArray = jsonDict["amiibo"] as? [[String: Any]] else {
            struct MissingAmiiboArrayError: LocalizedError {
                var errorDescription: String? { "amiibo.json missing 'amiibo' array" }
            }
            throw MissingAmiiboArrayError()
        }
        cachedAmiiboList = AmiiboCatalogSync.buildAmiiboListResponseForBundle(from: amiiboArray)

        guard let gamesURL = bundleURL(forResource: "games_info", extension: "json") else {
            struct FileNotFoundError: LocalizedError {
                var errorDescription: String? { "games_info.json NOT FOUND in bundle" }
            }
            throw FileNotFoundError()
        }
        let gamesData = try Data(contentsOf: gamesURL)
        let gamesObject = try JSONSerialization.jsonObject(with: gamesData, options: [.allowFragments])
        guard let amiibosObject = gamesObject as? [String: Any],
              let amiibosDict = amiibosObject["amiibos"] as? [String: Any] else {
            struct MissingAmiibosKeyError: LocalizedError {
                var errorDescription: String? { "'amiibos' key not found in games_info.json" }
            }
            throw MissingAmiibosKeyError()
        }
        var gamesDataRaw: [String: [String: Any]] = [:]
        for (key, value) in amiibosDict {
            if let valueDict = value as? [String: Any] {
                gamesDataRaw[key] = valueDict
            }
        }
        cachedGamesDataRaw = gamesDataRaw
    }

    // MARK: - Load Amiibo List

    func fetchAmiiboList() -> AnyPublisher<AmiiboListResponse, Error> {
        Future<AmiiboListResponse, Error> { promise in
            self.ensureCatalogOrBundled { error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                if let list = self.cachedAmiiboList {
                    promise(.success(list))
                } else {
                    promise(.failure(NetworkError.invalidURL))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Load Compatibility Data

    func fetchAmiiboConsoles(tail: String) -> AnyPublisher<Games, Error> {
        do {
            if cachedGamesDataRaw == nil || cachedAmiiboList == nil {
                let sem = DispatchSemaphore(value: 0)
                var ensureError: Error?
                ensureCatalogOrBundled { err in
                    ensureError = err
                    sem.signal()
                }
                sem.wait()
                if let e = ensureError {
                    return Fail(error: e).eraseToAnyPublisher()
                }
            }

            guard let amiiboResponse = cachedAmiiboList else {
                struct NoAmiiboDataError: LocalizedError {
                    var errorDescription: String? { "Failed to get amiibo list for compatibility" }
                }
                return Fail(error: NoAmiiboDataError()).eraseToAnyPublisher()
            }

            let normalizedTailForSearch: String
            if tail.hasPrefix("0x") || tail.hasPrefix("0X") {
                normalizedTailForSearch = String(tail.dropFirst(2))
            } else {
                normalizedTailForSearch = tail
            }

            let amiibo = amiiboResponse.amiibo.first { amiibo in
                let amiiboTail: String
                if amiibo.tail.hasPrefix("0x") || amiibo.tail.hasPrefix("0X") {
                    amiiboTail = String(amiibo.tail.dropFirst(2))
                } else {
                    amiiboTail = amiibo.tail
                }
                return amiiboTail == normalizedTailForSearch
            }

            guard let foundAmiibo = amiibo else {
                struct AmiiboNotFoundError: LocalizedError {
                    var errorDescription: String? { "Amiibo metadata not found for tail" }
                }
                return Fail(error: AmiiboNotFoundError()).eraseToAnyPublisher()
            }

            let normalizedHead: String
            if foundAmiibo.head.hasPrefix("0x") || foundAmiibo.head.hasPrefix("0X") {
                normalizedHead = String(foundAmiibo.head.dropFirst(2))
            } else {
                normalizedHead = foundAmiibo.head
            }

            let normalizedTail: String
            if foundAmiibo.tail.hasPrefix("0x") || foundAmiibo.tail.hasPrefix("0X") {
                normalizedTail = String(foundAmiibo.tail.dropFirst(2))
            } else {
                normalizedTail = foundAmiibo.tail
            }

            let fullId = "0x\(normalizedHead)\(normalizedTail)"

            let gamesDataRaw = cachedGamesDataRaw?[fullId]
                ?? cachedGamesDataRaw?["0x\(foundAmiibo.head)\(foundAmiibo.tail)"]
                ?? cachedGamesDataRaw?["0x\(normalizedTail)"]
                ?? cachedGamesDataRaw?[tail]

            guard let foundGamesDataRaw = gamesDataRaw else {
                struct GamesNotFoundError: LocalizedError {
                    var errorDescription: String? { "Amiibo games data not found for tail" }
                }
                return Fail(error: GamesNotFoundError()).eraseToAnyPublisher()
            }

            let games3DS = (foundGamesDataRaw["games3DS"] as? [[String: Any]])?.map { gameDict -> Games3DS in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    return AmiiboUsage(usage: usage, write: write)
                } ?? []
                return Games3DS(amiiboUsage: amiiboUsage, gameID: gameID, gameName: gameName)
            } ?? []

            let gamesSwitch = (foundGamesDataRaw["gamesSwitch"] as? [[String: Any]])?.map { gameDict -> GamesSwitch in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    return AmiiboUsage(usage: usage, write: write)
                } ?? []
                return GamesSwitch(amiiboUsage: amiiboUsage, gameID: gameID, gameName: gameName)
            } ?? []

            let gamesWiiU = (foundGamesDataRaw["gamesWiiU"] as? [[String: Any]])?.map { gameDict -> GamesWiiU in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    return AmiiboUsage(usage: usage, write: write)
                } ?? []
                return GamesWiiU(amiiboUsage: amiiboUsage, gameID: gameID, gameName: gameName)
            } ?? []

            let gamesSwitch2 = (foundGamesDataRaw["gamesSwitch2"] as? [[String: Any]])?.map { gameDict -> GamesSwitch in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    return AmiiboUsage(usage: usage, write: write)
                } ?? []
                return GamesSwitch(amiiboUsage: amiiboUsage, gameID: gameID, gameName: gameName)
            } ?? []

            let amiiboGames = AmiiboGames(
                amiiboSeries: foundAmiibo.amiiboSeries,
                character: foundAmiibo.character,
                gameSeries: foundAmiibo.gameSeries,
                games3DS: games3DS,
                gamesSwitch: gamesSwitch,
                gamesSwitch2: gamesSwitch2,
                gamesWiiU: gamesWiiU,
                head: foundAmiibo.head,
                image: foundAmiibo.image,
                name: foundAmiibo.name,
                release: foundAmiibo.release ?? Release(),
                tail: foundAmiibo.tail,
                type: foundAmiibo.type
            )

            let games = Games(amiibo: [amiiboGames])
            return Just(games)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()

        } catch let error as NSError {
            var errorMsg = "Error reading local JSON: \(error.localizedDescription)\n\nDomain: \(error.domain)\nCode: \(error.code)"
            if let debugDesc = error.userInfo["NSDebugDescription"] as? String {
                errorMsg += "\n\nDebug: \(debugDesc)"
            }
            struct CompatibilityError: LocalizedError {
                let errorDescription: String?
                init(_ message: String) { self.errorDescription = message }
            }
            return Fail(error: CompatibilityError(errorMsg)).eraseToAnyPublisher()
        } catch {
            struct CompatibilityError: LocalizedError {
                let errorDescription: String?
                init(_ message: String) { self.errorDescription = message }
            }
            return Fail(error: CompatibilityError("Error reading local JSON: \(error.localizedDescription)"))
                .eraseToAnyPublisher()
        }
    }

    private func parseWriteValue(_ value: Any?) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            return stringValue.lowercased() == "true"
        }
        return false
    }
}
