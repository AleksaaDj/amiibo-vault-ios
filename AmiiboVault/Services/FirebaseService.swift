import Foundation
import Firebase
import FirebaseDatabase

class FirebaseService {
    static let shared = FirebaseService()
    private let database = Database.database()
    private let ref: DatabaseReference
    
    private init() {
        ref = database.reference()
    }
    
    // MARK: - RAWG API key (same node as Android: `/Rawg`)
    func fetchRawgApiKey(completion: @escaping (Result<String, Error>) -> Void) {
        ref.child("Rawg").observeSingleEvent(of: .value) { snapshot in
            guard let key = snapshot.value as? String else {
                completion(.failure(FirebaseError.noData))
                return
            }
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                completion(.failure(FirebaseError.invalidData))
                return
            }
            completion(.success(trimmed))
        }
    }

    // MARK: - Featured Amiibo
    func fetchFeaturedAmiibo(completion: @escaping (Result<FirebaseFeaturedAmiibo, Error>) -> Void) {
        ref.child("Amiibo").observeSingleEvent(of: .value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                completion(.failure(FirebaseError.noData))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: value)
                let featuredData = try JSONDecoder().decode(FirebaseFeaturedAmiibo.self, from: jsonData)
                completion(.success(featuredData))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Listen to Featured Amiibo Changes
    func listenToFeaturedAmiiboChanges(completion: @escaping (Result<FirebaseFeaturedAmiibo, Error>) -> Void) {
        ref.child("Amiibo").observe(.value) { snapshot in
            guard let value = snapshot.value as? [String: Any] else {
                completion(.failure(FirebaseError.noData))
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: value)
                let featuredData = try JSONDecoder().decode(FirebaseFeaturedAmiibo.self, from: jsonData)
                completion(.success(featuredData))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Data Models
struct FirebaseFeaturedAmiibo: Codable {
    let image: String
    let tail: String
    
    enum CodingKeys: String, CodingKey {
        case image, tail
    }
}

// MARK: - Errors
enum FirebaseError: Error, LocalizedError {
    case noData
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No featured Amiibo data found"
        case .invalidData:
            return "Invalid featured Amiibo data"
        }
    }
}
