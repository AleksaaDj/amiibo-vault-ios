import Foundation
import FirebaseDatabase

/// Loads `catalog` (version, amiibo, gamesInfo) from Firebase Realtime Database with disk cache.
/// Matches Android `AmiiboCatalogSync` / `Constants.SHARED_PREFERENCES_CATALOG_VERSION`.
final class AmiiboCatalogSync {
    static let shared = AmiiboCatalogSync()

    private let catalogRef = Database.database().reference().child("catalog")
    private let prefsKey = "cached_catalog_version"
    private let cacheSubdirectory = "catalog_cache"
    private let fileAmiibo = "amiibo_cache.json"
    private let fileGames = "games_cache.json"

    private init() {}

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(cacheSubdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// - Returns: `(amiibo list, games map)` on success; `(nil, nil)` if caller should load bundled JSON.
    func tryLoadCatalog(completion: @escaping (AmiiboListResponse?, [String: [String: Any]]?) -> Void) {
        let savedVersion = readCachedCatalogVersion()

        // `observeSingleEvent` can return persisted RTDB cache first, so `version` may lag the console
        // after a bump until reinstall. `getData` is documented to fetch the most up-to-date value when online.
        catalogRef.child("version").getData { [weak self] error, snapshot in
            guard let self = self else {
                completion(nil, nil)
                return
            }
            guard error == nil, let snapshot = snapshot else {
                self.loadFromDiskCache(completion: completion)
                return
            }
            let remote = self.snapshotToInt64(snapshot)
            if remote > savedVersion {
                self.fetchPersistAndParse(remoteVersion: remote, completion: completion)
            } else {
                self.loadFromDiskCache(completion: completion)
            }
        }
    }

    private func fetchPersistAndParse(
        remoteVersion: Int64,
        completion: @escaping (AmiiboListResponse?, [String: [String: Any]]?) -> Void
    ) {
        catalogRef.child("amiibo").getData { [weak self] amiiboError, amiiboSnapshot in
            guard let self = self else {
                completion(nil, nil)
                return
            }
            guard amiiboError == nil, let amiiboSnapshot = amiiboSnapshot else {
                self.loadFromDiskCache(completion: completion)
                return
            }
            self.catalogRef.child("gamesInfo").getData { gamesError, gamesSnapshot in
                guard gamesError == nil, let gamesSnapshot = gamesSnapshot else {
                    self.loadFromDiskCache(completion: completion)
                    return
                }
                guard let amiiboList = self.parseAmiiboSnapshot(amiiboSnapshot),
                      let gamesMap = self.parseGamesSnapshot(gamesSnapshot) else {
                    self.loadFromDiskCache(completion: completion)
                    return
                }
                self.persistToDisk(amiiboSnapshot: amiiboSnapshot, gamesSnapshot: gamesSnapshot)
                UserDefaults.standard.set(remoteVersion, forKey: self.prefsKey)
                completion(amiiboList, gamesMap)
            }
        }
    }

    /// Firebase RTDB stores JSON arrays as dictionaries with "0", "1", … keys, not `[[String: Any]]`.
    private func amiiboArray(from value: Any?) -> [[String: Any]]? {
        guard let value = value else { return nil }
        if let arr = value as? [[String: Any]] { return arr }
        if let dict = value as? [String: Any] {
            let keys = dict.keys.compactMap { Int($0) }
            guard !dict.isEmpty else { return [] }
            if keys.count == dict.count {
                return keys.sorted().compactMap { dict[String($0)] as? [String: Any] }
            }
            return dict.keys.sorted { (Int($0) ?? -1) < (Int($1) ?? -1) }.compactMap { dict[$0] as? [String: Any] }
        }
        if let dict = value as? [Int: Any] {
            return dict.keys.sorted().compactMap { dict[$0] as? [String: Any] }
        }
        return nil
    }

    private func parseAmiiboSnapshot(_ snapshot: DataSnapshot) -> AmiiboListResponse? {
        guard let array = amiiboArray(from: snapshot.value) else { return nil }
        return Self.buildAmiiboListResponseForBundle(from: array)
    }

    private func parseGamesSnapshot(_ snapshot: DataSnapshot) -> [String: [String: Any]]? {
        guard let root = snapshot.value as? [String: Any],
              let amiibos = root["amiibos"] as? [String: Any] else { return nil }
        var out: [String: [String: Any]] = [:]
        for (key, val) in amiibos {
            if let dict = val as? [String: Any] {
                out[key] = dict
            }
        }
        return out
    }

    private func persistToDisk(amiiboSnapshot: DataSnapshot, gamesSnapshot: DataSnapshot) {
        let amiiboURL = cacheDirectory.appendingPathComponent(fileAmiibo)
        let gamesURL = cacheDirectory.appendingPathComponent(fileGames)
        if let raw = amiiboSnapshot.value, let arr = amiiboArray(from: raw) {
            let wrapped: [String: Any] = ["amiibo": arr]
            if let data = try? JSONSerialization.data(withJSONObject: wrapped, options: []) {
                try? data.write(to: amiiboURL, options: .atomic)
            }
        }
        if let gamesValue = gamesSnapshot.value {
            if let data = try? JSONSerialization.data(withJSONObject: gamesValue, options: []) {
                try? data.write(to: gamesURL, options: .atomic)
            }
        }
    }

    private func loadFromDiskCache(completion: @escaping (AmiiboListResponse?, [String: [String: Any]]?) -> Void) {
        let amiiboURL = cacheDirectory.appendingPathComponent(fileAmiibo)
        let gamesURL = cacheDirectory.appendingPathComponent(fileGames)
        guard FileManager.default.fileExists(atPath: amiiboURL.path),
              FileManager.default.fileExists(atPath: gamesURL.path) else {
            completion(nil, nil)
            return
        }
        do {
            let amiiboData = try Data(contentsOf: amiiboURL)
            let gamesData = try Data(contentsOf: gamesURL)
            guard let amiiboRoot = try JSONSerialization.jsonObject(with: amiiboData) as? [String: Any],
                  let amiiboArray = amiiboArray(from: amiiboRoot["amiibo"]),
                  let gamesRoot = try JSONSerialization.jsonObject(with: gamesData) as? [String: Any],
                  let amiibos = gamesRoot["amiibos"] as? [String: Any] else {
                completion(nil, nil)
                return
            }
            var gamesMap: [String: [String: Any]] = [:]
            for (key, val) in amiibos {
                if let dict = val as? [String: Any] { gamesMap[key] = dict }
            }
            let list = Self.buildAmiiboListResponseForBundle(from: amiiboArray)
            completion(list, gamesMap)
        } catch {
            completion(nil, nil)
        }
    }

    private func readCachedCatalogVersion() -> Int64 {
        let raw = UserDefaults.standard.object(forKey: prefsKey)
        switch raw {
        case let n as Int64: return n
        case let n as Int: return Int64(n)
        case let n as NSNumber: return n.int64Value
        case let s as String: return Int64(s) ?? 0
        default: return 0
        }
    }

    private func snapshotToInt64(_ snapshot: DataSnapshot) -> Int64 {
        guard let v = snapshot.value else { return 0 }
        switch v {
        case let n as Int64: return n
        case let n as Int: return Int64(n)
        case let n as Double: return Int64(n)
        case let n as NSNumber: return n.int64Value
        case let s as String: return Int64(s) ?? 0
        default: return 0
        }
    }
}

extension AmiiboCatalogSync {
    /// Shared with `LocalJsonService` bundled JSON path.
    static func buildAmiiboListResponseForBundle(from amiiboArray: [[String: Any]]) -> AmiiboListResponse {
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
            var release: Release?
            if let releaseDict = item["release"] as? [String: Any] {
                release = Release(
                    au: releaseDict["au"] as? String,
                    eu: releaseDict["eu"] as? String,
                    jp: releaseDict["jp"] as? String,
                    na: releaseDict["na"] as? String
                )
            }
            amiibos.append(
                Amiibo(
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
            )
        }
        return AmiiboListResponse(amiibo: amiibos)
    }
}
