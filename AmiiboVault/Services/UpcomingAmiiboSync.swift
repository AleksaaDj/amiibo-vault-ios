import Foundation
import FirebaseDatabase

/// Loads `/upcoming` from Firebase RTDB with disk cache. No bundled JSON in the app.
final class UpcomingAmiiboSync {
    static let shared = UpcomingAmiiboSync()

    private let upcomingRef = Database.database().reference().child("upcoming")
    private let prefsKey = "cached_upcoming_version"
    private let cacheSubdirectory = "upcoming_cache"
    private let fileItems = "upcoming_items.json"

    private init() {}

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(cacheSubdirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func tryLoadUpcoming(completion: @escaping (UpcomingAmiiboListResponse?) -> Void) {
        let cachedVersion = readCachedVersion()

        upcomingRef.child("version").getData { [weak self] error, snapshot in
            guard let self else {
                completion(nil)
                return
            }
            guard error == nil, let snapshot else {
                self.loadFromDiskCache(completion: completion)
                return
            }
            let remoteVersion = self.snapshotToInt64(snapshot)
            if remoteVersion > cachedVersion {
                self.fetchPersistAndParse(remoteVersion: remoteVersion, completion: completion)
            } else {
                self.loadFromDiskCache { cached in
                    if let cached {
                        completion(cached)
                    } else if remoteVersion > 0 {
                        self.fetchPersistAndParse(remoteVersion: remoteVersion, completion: completion)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    private func fetchPersistAndParse(remoteVersion: Int64, completion: @escaping (UpcomingAmiiboListResponse?) -> Void) {
        upcomingRef.child("items").getData { [weak self] error, snapshot in
            guard let self else {
                completion(nil)
                return
            }
            guard error == nil, let snapshot, let response = self.parseItemsSnapshot(snapshot) else {
                self.loadFromDiskCache(completion: completion)
                return
            }
            self.persistToDisk(snapshot: snapshot)
            UserDefaults.standard.set(remoteVersion, forKey: self.prefsKey)
            completion(response)
        }
    }

    private func parseItemsSnapshot(_ snapshot: DataSnapshot) -> UpcomingAmiiboListResponse? {
        guard let array = amiiboArray(from: snapshot.value) else { return nil }
        do {
            let data = try JSONSerialization.data(withJSONObject: array)
            let items = try JSONDecoder().decode([UpcomingAmiibo].self, from: data)
            return UpcomingAmiiboListResponse(items: items)
        } catch {
            return nil
        }
    }

    private func persistToDisk(snapshot: DataSnapshot) {
        guard let array = amiiboArray(from: snapshot.value) else { return }
        let url = cacheDirectory.appendingPathComponent(fileItems)
        do {
            let wrapped: [String: Any] = ["items": array]
            let data = try JSONSerialization.data(withJSONObject: wrapped, options: [])
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist upcoming cache: \(error)")
        }
    }

    private func loadFromDiskCache(completion: @escaping (UpcomingAmiiboListResponse?) -> Void) {
        let url = cacheDirectory.appendingPathComponent(fileItems)
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(nil)
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let response = try JSONDecoder().decode(UpcomingAmiiboListResponse.self, from: data)
            completion(response)
        } catch {
            completion(nil)
        }
    }

    private func amiiboArray(from value: Any?) -> [[String: Any]]? {
        guard let value else { return nil }
        if let arr = value as? [[String: Any]] { return arr }
        if let dict = value as? [String: Any] {
            let keys = dict.keys.compactMap { Int($0) }
            guard !dict.isEmpty else { return [] }
            if keys.count == dict.count {
                return keys.sorted().compactMap { dict[String($0)] as? [String: Any] }
            }
            return dict.keys.sorted { (Int($0) ?? -1) < (Int($1) ?? -1) }.compactMap { dict[$0] as? [String: Any] }
        }
        return nil
    }

    private func readCachedVersion() -> Int64 {
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
        case let s as String: return Int64(s) ?? 0
        default: return 0
        }
    }
}
