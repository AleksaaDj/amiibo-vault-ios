import Foundation
import Firebase
import FirebaseDatabase

class FirebaseService {
    static let shared = FirebaseService()
    private let database = Database.database()
    private let ref: DatabaseReference
    
    private init() {
        print("🔥 Firebase: Initializing Firebase service...")
        ref = database.reference()
        print("✅ Firebase: Firebase service initialized successfully")
    }
    
    // MARK: - Featured Amiibo
    func fetchFeaturedAmiibo(completion: @escaping (Result<FirebaseFeaturedAmiibo, Error>) -> Void) {
        print("🔥 Firebase: Attempting to fetch featured Amiibo...")
        ref.child("Amiibo").observeSingleEvent(of: .value) { snapshot in
            print("🔥 Firebase: Snapshot received: \(snapshot.exists())")
            
            guard let value = snapshot.value as? [String: Any] else {
                print("❌ Firebase: No data found in snapshot")
                completion(.failure(FirebaseError.noData))
                return
            }
            
            print("✅ Firebase: Data found: \(value)")
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: value)
                let featuredData = try JSONDecoder().decode(FirebaseFeaturedAmiibo.self, from: jsonData)
                print("✅ Firebase: Successfully decoded featured Amiibo: \(featuredData.tail)")
                completion(.success(featuredData))
            } catch {
                print("❌ Firebase: Failed to decode data: \(error)")
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
