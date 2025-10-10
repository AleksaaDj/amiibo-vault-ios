import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    let content: (AsyncImagePhase) -> Content
    let placeholder: () -> Placeholder
    
    @State private var phase: AsyncImagePhase = .empty
    @State private var isLoading = false
    
    init(
        url: String,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        content(phase)
            .onAppear {
                loadImage()
            }
    }
    
    private func loadImage() {
        // Check cache first
        if let cachedImage = ImageCacheService.shared.getImage(from: url) {
            self.phase = .success(Image(uiImage: cachedImage))
            return
        }
        
        // Load from network
        isLoading = true
        phase = .empty
        
        guard let imageURL = URL(string: url) else {
            phase = .failure(URLError(.badURL))
            return
        }
        
        URLSession.shared.dataTask(with: imageURL) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    self.phase = .failure(error)
                } else if let data = data, let image = UIImage(data: data) {
                    // Cache the image
                    ImageCacheService.shared.setImage(image, for: url)
                    self.phase = .success(Image(uiImage: image))
                } else {
                    self.phase = .failure(URLError(.badServerResponse))
                }
            }
        }.resume()
    }
}