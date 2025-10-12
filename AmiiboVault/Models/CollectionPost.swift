import Foundation

struct CollectionPost: Codable, Identifiable {
    let id = UUID()
    let postId: String?
    let likes: String?
    let avatarId: Int?
    let backgroundColor: Int?
    let date: String?
    let image: String?
    let name: String?
    let text: String?
    
    enum CodingKeys: String, CodingKey {
        case postId, likes, avatarId, backgroundColor, date, image, name, text
    }
}





