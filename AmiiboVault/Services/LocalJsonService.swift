import Foundation
import Combine
import os.log

// MARK: - Local JSON Service
// TEMPORARY: Using local JSON files while server is down
// TODO: When server is fixed, uncomment the API calls in NetworkService and comment out LocalJsonService usage
class LocalJsonService {
    static let shared = LocalJsonService()

    private let logger = Logger(subsystem: "com.softwavegamess.AmiiboVaultApp", category: "LocalJsonService")

    private var cachedAmiiboList: AmiiboListResponse?
    private var cachedGamesDataRaw: [String: [String: Any]]?

    private init() {
    }
    
    // MARK: - Load Amiibo List
    func fetchAmiiboList() -> AnyPublisher<AmiiboListResponse, Error> {
        // Return cached data if available
        if let cached = cachedAmiiboList {
            return Just(cached)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Parse synchronously like Android (Gson does it synchronously on IO thread)
        do {
            // Find file synchronously
            var url: URL?
            url = Bundle.main.url(forResource: "amiibo", withExtension: "json")
            
            if url == nil, let resourcePath = Bundle.main.resourcePath {
                let directPath = "\(resourcePath)/amiibo.json"
                if FileManager.default.fileExists(atPath: directPath) {
                    url = URL(fileURLWithPath: directPath)
                }
            }
            
            if url == nil, let resourcePath = Bundle.main.resourcePath {
                let assetsPath = "\(resourcePath)/Assets/amiibo.json"
                if FileManager.default.fileExists(atPath: assetsPath) {
                    url = URL(fileURLWithPath: assetsPath)
                }
            }
            
            guard let fileUrl = url else {
                return Fail(error: NetworkError.invalidURL)
                    .eraseToAnyPublisher()
            }
            
            // Read and parse synchronously (like Android Gson)
            let data = try Data(contentsOf: fileUrl)
            
            // Parse JSON synchronously (like Android Gson)
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
            
            guard let jsonDict = jsonObject as? [String: Any] else {
                struct InvalidJsonStructureError: LocalizedError {
                    var errorDescription: String? { return "amiibo.json root is not a dictionary" }
                }
                return Fail(error: InvalidJsonStructureError())
                    .eraseToAnyPublisher()
            }
            
            guard let amiiboArray = jsonDict["amiibo"] as? [[String: Any]] else {
                let rootKeys = jsonDict.keys.joined(separator: ", ")
                struct MissingAmiiboArrayError: LocalizedError {
                    let keys: String
                    var errorDescription: String? { return "amiibo.json missing 'amiibo' array. Root keys: \(keys)" }
                }
                return Fail(error: MissingAmiiboArrayError(keys: rootKeys))
                    .eraseToAnyPublisher()
            }
            
            // Parse synchronously (like Android Gson - very fast)
            var amiibos: [Amiibo] = []
            amiibos.reserveCapacity(amiiboArray.count)
            
            for item in amiiboArray {
                let amiiboSeries = item["amiiboSeries"] as? String ?? ""
                let character = item["character"] as? String ?? ""
                let gameSeries = item["gameSeries"] as? String ?? ""
                let head = item["head"] as? String ?? ""
                let image = item["image"] as? String ?? ""
                let name = item["name"] as? String ?? ""
                let tail = item["tail"] as? String ?? ""
                let type = item["type"] as? String ?? ""
                
                var release: Release? = nil
                if let releaseDict = item["release"] as? [String: Any] {
                    release = Release(
                        au: releaseDict["au"] as? String,
                        eu: releaseDict["eu"] as? String,
                        jp: releaseDict["jp"] as? String,
                        na: releaseDict["na"] as? String
                    )
                }
                
                let amiibo = Amiibo(
                    amiiboSeries: amiiboSeries,
                    character: character,
                    gameSeries: gameSeries,
                    head: head,
                    image: image,
                    name: name,
                    release: release,
                    tail: tail,
                    type: type,
                    featured: false,
                    color: 0,
                    isInCollection: false,
                    isInWishlist: false
                )
                amiibos.append(amiibo)
            }
            
            let response = AmiiboListResponse(amiibo: amiibos)
            cachedAmiiboList = response
            
            // Return immediately (like Android)
            return Just(response)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
                
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
    
    // MARK: - Load Compatibility Data
    func fetchAmiiboConsoles(tail: String) -> AnyPublisher<Games, Error> {
        // Parse synchronously like Android (Gson does it synchronously on IO thread)
        // Android: suspend fun getAmiiboConsoles(tail: String): Response<Games> = withContext(Dispatchers.IO) {
        do {
            // Load games data if not cached (EXACTLY like Android line 62)
            if cachedGamesDataRaw == nil {
                // Android: val inputStream: InputStream = context.resources.openRawResource(R.raw.games_info)
                // Read games_info.json EXACTLY the same way as amiibo.json
                var url: URL?
                url = Bundle.main.url(forResource: "games_info", withExtension: "json")
                
                if url == nil, let resourcePath = Bundle.main.resourcePath {
                    let directPath = "\(resourcePath)/games_info.json"
                    if FileManager.default.fileExists(atPath: directPath) {
                        url = URL(fileURLWithPath: directPath)
                    }
                }
                
                if url == nil, let resourcePath = Bundle.main.resourcePath {
                    let assetsPath = "\(resourcePath)/Assets/games_info.json"
                    if FileManager.default.fileExists(atPath: assetsPath) {
                        url = URL(fileURLWithPath: assetsPath)
                    }
                }
                
                guard let fileUrl = url else {
                    struct FileNotFoundError: LocalizedError {
                        var errorDescription: String? { return "games_info.json NOT FOUND in bundle" }
                    }
                    return Fail(error: FileNotFoundError())
                        .eraseToAnyPublisher()
                }
                
                // Android: val jsonString = inputStream.bufferedReader().use { it.readText() }
                // Read file synchronously (EXACTLY like fetchAmiiboList reads amiibo.json)
                let data = try Data(contentsOf: fileUrl)
                
                // Android: val jsonObject = JsonParser.parseString(jsonString).asJsonObject
                // Android: val amiibosObject = jsonObject.getAsJsonObject("amiibos")
                // Parse JSON synchronously
                let jsonObject: Any
                do {
                    jsonObject = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                } catch let parseError as NSError {
                    var errorMsg = "Failed to parse games_info.json:\n\nDomain: \(parseError.domain)\nCode: \(parseError.code)\nError: \(parseError.localizedDescription)"
                    
                    // Get debug description if available
                    if let debugDesc = parseError.userInfo["NSDebugDescription"] as? String {
                        errorMsg += "\n\nDebug: \(debugDesc)"
                    }
                    
                    struct JsonParseError: LocalizedError {
                        let message: String
                        var errorDescription: String? { return message }
                    }
                    
                    return Fail(error: JsonParseError(message: errorMsg))
                        .eraseToAnyPublisher()
                }
                
                guard let amiibosObject = jsonObject as? [String: Any] else {
                    struct InvalidJsonError: LocalizedError {
                        var errorDescription: String? { return "games_info.json root is not a dictionary" }
                    }
                    return Fail(error: InvalidJsonError())
                        .eraseToAnyPublisher()
                }
                
                guard let amiibosDict = amiibosObject["amiibos"] as? [String: Any] else {
                    let rootKeys = amiibosObject.keys.joined(separator: ", ")
                    struct MissingAmiibosKeyError: LocalizedError {
                        let keys: String
                        var errorDescription: String? { return "'amiibos' key not found in games_info.json. Root keys: \(keys)" }
                    }
                    return Fail(error: MissingAmiibosKeyError(keys: rootKeys))
                        .eraseToAnyPublisher()
                }
                
                // Android line 69-71: Cache all games data
                // Android: cachedGamesData = amiibosObject.entrySet().associate { entry -> entry.key to gson.fromJson(entry.value, GamesJsonItem::class.java) }
                // iOS: Cache raw dictionaries (parse on demand to match Android's structure)
                var gamesDataRaw: [String: [String: Any]] = [:]
                for (key, value) in amiibosDict {
                    if let valueDict = value as? [String: Any] {
                        gamesDataRaw[key] = valueDict
                    }
                }
                cachedGamesDataRaw = gamesDataRaw
            }
            
            // Get the amiibo data first to get the head value (EXACTLY like Android line 75)
            // Android: val amiiboListResponse = getAmiiboList()
            var amiiboResponse: AmiiboListResponse?
            
            if let cached = cachedAmiiboList {
                amiiboResponse = cached
            } else {
                // Fetch synchronously - use semaphore to wait for publisher
                let semaphore = DispatchSemaphore(value: 0)
                var fetchError: Error?
                
                _ = fetchAmiiboList()
                    .sink(
                        receiveCompletion: { completion in
                            if case .failure(let error) = completion {
                                fetchError = error
                            }
                            semaphore.signal()
                        },
                        receiveValue: { response in
                            amiiboResponse = response
                        }
                    )
                
                semaphore.wait()
            }
            
            // Android: val amiiboListResponse = getAmiiboList()
            // Android: val amiibo = amiiboListResponse.body()?.amiibo?.firstOrNull { ... }
            // iOS: use amiiboResponse.amiibo directly (no .body() needed)
            guard let amiiboResponse = amiiboResponse else {
                struct NoAmiiboDataError: LocalizedError {
                    var errorDescription: String? { return "Failed to get amiibo list for compatibility" }
                }
                return Fail(error: NoAmiiboDataError())
                    .eraseToAnyPublisher()
            }
            
            // Android line 77: val normalizedTailForSearch = tail.removePrefix("0x").removePrefix("0X")
            // removePrefix only removes from START - EXACTLY match Android
            let normalizedTailForSearch: String
            if tail.hasPrefix("0x") || tail.hasPrefix("0X") {
                normalizedTailForSearch = String(tail.dropFirst(2))
            } else {
                normalizedTailForSearch = tail
            }
            
            // Android line 78-80: Find amiibo by tail
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
                    var errorDescription: String? { return "Amiibo metadata not found for tail" }
                }
                return Fail(error: AmiiboNotFoundError())
                    .eraseToAnyPublisher()
            }
            
            // Android line 89-91: Normalize head and tail
            // games_info.json uses full ID format: "0x" + head + tail (16 characters total)
            // Example: head="00000000" + tail="02380602" = "0x0000000002380602"
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
            
            // Android line 91: val fullId = "0x$normalizedHead$normalizedTail"
            let fullId = "0x\(normalizedHead)\(normalizedTail)"
            
            // Android line 94-97: Try multiple formats just in case
            // Android tries: fullId, "0x${amiibo.head}${amiibo.tail}", "0x$normalizedTail", tail
            let gamesDataRaw = cachedGamesDataRaw?[fullId]
                ?? cachedGamesDataRaw?["0x\(foundAmiibo.head)\(foundAmiibo.tail)"]
                ?? cachedGamesDataRaw?["0x\(normalizedTail)"]
                ?? cachedGamesDataRaw?[tail]
            
            guard let foundGamesDataRaw = gamesDataRaw else {
                struct GamesNotFoundError: LocalizedError {
                    var errorDescription: String? { return "Amiibo games data not found for tail" }
                }
                return Fail(error: GamesNotFoundError())
                    .eraseToAnyPublisher()
            }
            
            // Android line 105-143: Convert to AmiiboGames format
            // Parse manually from raw dictionary (like Android's Gson)
            let games3DS = (foundGamesDataRaw["games3DS"] as? [[String: Any]])?.map { gameDict -> Games3DS in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    // JSON has "Usage" (capital U) and "write" (lowercase)
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    // Use memberwise initializer - this bypasses Codable
                    return AmiiboUsage(usage: usage, write: write)
                } ?? []
                return Games3DS(amiiboUsage: amiiboUsage, gameID: gameID, gameName: gameName)
            } ?? []
            
            let gamesSwitch = (foundGamesDataRaw["gamesSwitch"] as? [[String: Any]])?.map { gameDict -> GamesSwitch in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    // JSON has "Usage" (capital U) and "write" (lowercase)
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    // Use memberwise initializer - this bypasses Codable
                    return AmiiboUsage(usage: usage, write: write)
                } ?? []
                return GamesSwitch(amiiboUsage: amiiboUsage, gameID: gameID, gameName: gameName)
            } ?? []
            
            let gamesWiiU = (foundGamesDataRaw["gamesWiiU"] as? [[String: Any]])?.map { gameDict -> GamesWiiU in
                let gameID = gameDict["gameID"] as? [String] ?? []
                let gameName = gameDict["gameName"] as? String ?? ""
                let amiiboUsage = (gameDict["amiiboUsage"] as? [[String: Any]])?.map { usageDict -> AmiiboUsage in
                    // JSON has "Usage" (capital U) and "write" (lowercase)
                    let usage = usageDict["Usage"] as? String ?? ""
                    let writeValue = usageDict["write"]
                    let write = parseWriteValue(writeValue)
                    // Use memberwise initializer - this bypasses Codable
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
            
            // Android line 145-158: Create AmiiboGames
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
            
            // Android line 160: Response.success(Games(listOf(amiiboGames)))
            let games = Games(amiibo: [amiiboGames])
            
            // Return immediately (like Android)
            return Just(games)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
                
        } catch let error as NSError {
            // Android line 161-163: catch (e: Exception) and return Response.error(500, ...)
            var errorMsg = "Error reading local JSON: \(error.localizedDescription)\n\nDomain: \(error.domain)\nCode: \(error.code)"
            
            // Get debug description if available
            if let debugDesc = error.userInfo["NSDebugDescription"] as? String {
                errorMsg += "\n\nDebug: \(debugDesc)"
            }
            
            // Get coding path if available
            if let codingPath = error.userInfo["NSCodingPath"] as? [String] {
                errorMsg += "\n\nPath: \(codingPath.joined(separator: " -> "))"
            }
            
            // Get underlying error if available
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                errorMsg += "\n\nUnderlying: \(underlyingError.localizedDescription)"
            }
            
            struct CompatibilityError: LocalizedError {
                let errorDescription: String?
                init(_ message: String) {
                    self.errorDescription = message
                }
            }
            
            return Fail(error: CompatibilityError(errorMsg))
                .eraseToAnyPublisher()
        } catch {
            struct CompatibilityError: LocalizedError {
                let errorDescription: String?
                init(_ message: String) {
                    self.errorDescription = message
                }
            }
            let errorMsg = "Error reading local JSON: \(error.localizedDescription)"
            return Fail(error: CompatibilityError(errorMsg))
                .eraseToAnyPublisher()
        }
    }
    
    // Helper function to parse write value (can be Boolean or String)
    private func parseWriteValue(_ value: Any?) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        } else if let stringValue = value as? String {
            return stringValue.lowercased() == "true"
        }
        return false
    }
}
