import Foundation
import SwiftUI
import Firebase
import PhotosUI
import Combine

class CreatePostViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var selectedImage: UIImage?
    @Published var selectedAvatarIndex: Int = 0
    @Published var selectedBackgroundIndex: Int = 0
    @Published var isUploading: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var showAvatarPicker: Bool = false
    @Published var postPublished: Bool = false
    
    private let database = Database.database().reference()
    
    // Avatar colors matching Android implementation exactly
    let avatarColors: [Color] = [
        Color(red: 0.937, green: 0.325, blue: 0.314), // #EF5350 - red_avatar (1)
        Color(red: 0.835, green: 0.486, blue: 0.894), // #D57CE4 - pink_avatar (2)
        Color(red: 0.161, green: 0.714, blue: 0.965), // #29B6F6 - blue_avatar (3)
        Color(red: 0.071, green: 0.071, blue: 0.071), // #121212 - black_avatar (4)
        Color(red: 0.992, green: 0.847, blue: 0.208), // #FDD835 - yellow_avatar (5)
        Color(red: 0.376, green: 0.180, blue: 0.416), // #602E6A - purple_avatar (6)
        Color(red: 0.149, green: 0.651, blue: 0.604), // #26A69A - teal_avatar (7)
        Color(red: 0.502, green: 0.502, blue: 0.0),   // #808000 - olive_avatar (8)
        Color(red: 0.357, green: 0.357, blue: 0.357), // #5B5B5B - grey_avatar (9)
        Color(red: 0.4, green: 0.733, blue: 0.416)    // #66BB6A - green_avatar (10)
    ]
    
    // Avatar images matching Android implementation exactly
    let avatarImages: [String] = [
        "link_avatar",      // 1 - LINK
        "peach_avatar",     // 2 - PEACH
        "mario_avatar",     // 3 - MARIO
        "alex_avatar",      // 4 - ALEX
        "bokoblin_avatar",  // 5 - BOKOBLIN
        "bowser_avatar",    // 6 - BOWSER
        "inkling_avatar",   // 7 - INKLING
        "isabelle_avatar",  // 8 - ISABELLE
        "kirby_avatar",     // 9 - KIRBY
        "lucina_avatar",    // 10 - LUCINA
        "nabiru_avatar",    // 11 - NABIRU
        "pikachu_avatar",   // 12 - PIKACHU
        "samus_avatar",     // 13 - SAMUS
        "yoshi_avatar"      // 14 - YOSHI
    ]
    
    // Color ID mapping for Firebase (matching Android ColorsIndex)
    let colorIds: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    // Avatar ID mapping for Firebase (matching Android AvatarsIndex)
    let avatarIds: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
    
    func publishPost() {
        guard !name.isEmpty else { return }
        
        isUploading = true
        
        // Generate postId same as Android: random number between 0 and 1000000
        let postId = String(Int.random(in: 0...1000000))
        
        // Format date same as Android: "dd/MM/yyyy HH:mm"
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: currentDate)
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarId = avatarIds[selectedAvatarIndex]
        let backgroundColor = colorIds[selectedBackgroundIndex]
        
        
        var postData: [String: Any] = [
            "postId": postId,
            "likes": "0",
            "avatarId": avatarId,
            "backgroundColor": backgroundColor,
            "date": dateString,
            "name": trimmedName,
            "text": trimmedText
        ]
        
        if let image = selectedImage {
            uploadImageToImgur(image) { [weak self] imageUrl in
                postData["image"] = imageUrl
                self?.savePostToFirebase(postData: postData)
            }
        } else {
            savePostToFirebase(postData: postData)
        }
    }
    
    private func uploadImageToImgur(_ image: UIImage, completion: @escaping (String) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion("")
            return
        }
        
        // Convert to base64
        let base64Image = imageData.base64EncodedString()
        
        // Imgur API endpoint
        guard let url = URL(string: "https://api.imgur.com/3/image") else {
            completion("")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Client-ID 67857bbca14679e", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["image": base64Image]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion("")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    completion("")
                }
                return
            }
            
            if let _ = response as? HTTPURLResponse {
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObject = json["data"] as? [String: Any],
                  let imageUrl = dataObject["link"] as? String else {
                DispatchQueue.main.async {
                    completion("")
                }
                return
            }
            
            // Add .jpg extension like Android does
            let finalUrl = imageUrl + ".jpg"
            
            DispatchQueue.main.async {
                completion(finalUrl)
            }
        }.resume()
    }
    
    private func savePostToFirebase(postData: [String: Any]) {
        let postId = postData["postId"] as! String
        database.child("SharedContent").child(postId).setValue(postData) { [weak self] error, _ in
            DispatchQueue.main.async {
                self?.isUploading = false
                if error == nil {
                    self?.postPublished = true
                    self?.resetForm()
                }
            }
        }
    }
    
    private func resetForm() {
        name = ""
        description = ""
        selectedImage = nil
        selectedAvatarIndex = 0
        selectedBackgroundIndex = 0
    }
}
