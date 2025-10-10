import Foundation
import Combine
import FirebaseDatabase

class PostsViewModel: ObservableObject {
    @Published var posts: [CollectionPost] = []
    @Published var likedPostIds: [String] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    private let database = Database.database().reference()
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let likedPostsKey = "liked_posts"
    
    init() {
        loadLikedPosts()
        loadPosts()
    }
    
    func loadPosts() {
        isLoading = true
        errorMessage = nil
        
        database.child("SharedContent").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                guard let data = snapshot.value as? [String: Any] else {
                    self.posts = []
                    return
                }
                
                var postsList: [CollectionPost] = []
                
                for (_, postData) in data {
                    if let postDict = postData as? [String: Any] {
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: postDict)
                            let post = try JSONDecoder().decode(CollectionPost.self, from: jsonData)
                            postsList.append(post)
                        } catch {
                            print("Error decoding post: \(error)")
                        }
                    }
                }
                
                // Sort posts by date (newest first)
                self.posts = postsList.sorted { post1, post2 in
                    guard let date1 = post1.date, let date2 = post2.date else { 
                        // If one has no date, put it at the end
                        return post1.date != nil
                    }
                    
                    // Parse dates for proper comparison
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd/MM/yyyy HH:mm"
                    
                    guard let parsedDate1 = formatter.date(from: date1),
                          let parsedDate2 = formatter.date(from: date2) else {
                        return date1 > date2 // Fallback to string comparison
                    }
                    
                    return parsedDate1 > parsedDate2
                }
            }
        }
    }
    
    func toggleLike(postId: String) {
        if likedPostIds.contains(postId) {
            likedPostIds.removeAll { $0 == postId }
        } else {
            likedPostIds.append(postId)
        }
        saveLikedPosts()
    }
    
    func isLiked(postId: String?) -> Bool {
        guard let postId = postId else { return false }
        return likedPostIds.contains(postId)
    }
    
    private func loadLikedPosts() {
        if let savedLikes = userDefaults.array(forKey: likedPostsKey) as? [String] {
            likedPostIds = savedLikes
        }
    }
    
    private func saveLikedPosts() {
        userDefaults.set(likedPostIds, forKey: likedPostsKey)
    }
}
