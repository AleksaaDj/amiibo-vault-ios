import SwiftUI
import Kingfisher

// MARK: - Collection Post Images (Firebase)
struct CollectionPostKingfisherImage: View {
    let url: String
    let height: CGFloat
    
    init(url: String, height: CGFloat = 280) {
        self.url = url
        self.height = height
    }
    
    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: height)
                    .overlay(
                        ProgressView()
                            .foregroundColor(.white)
                    )
            }
            .onFailure { _ in
                // Handle failure if needed
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: height)
            .clipped()
    }
}

// MARK: - Amiibo List Item Images
struct AmiiboListKingfisherImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(url: String, width: CGFloat = 80, height: CGFloat = 80, cornerRadius: CGFloat = 8, shadowRadius: CGFloat = 8) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                    )
            }
            .onFailure { _ in
                // Handle failure if needed
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.5), radius: shadowRadius, x: 0, y: 0)
    }
}

// MARK: - Amiibo Grid Item Images
struct AmiiboGridKingfisherImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let isDarkMode: Bool
    
    init(url: String, width: CGFloat = 110, height: CGFloat = 110, cornerRadius: CGFloat = 4, shadowRadius: CGFloat = 6, isDarkMode: Bool = false) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.isDarkMode = isDarkMode
    }
    
    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.133) : Color.white)
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                    )
            }
            .onFailure { _ in
                // Handle failure if needed
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.5), radius: shadowRadius, x: 0, y: 0)
            .padding(5)
    }
}

// MARK: - Amiibo Details Images
struct AmiiboDetailsKingfisherImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(url: String, width: CGFloat = 200, height: CGFloat = 200, cornerRadius: CGFloat = 8, shadowRadius: CGFloat = 10) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white)
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                    )
            }
            .onFailure { _ in
                // Handle failure if needed
            }
            .fade(duration: 0.15) // Smooth fade for better visual transitions
            .loadDiskFileSynchronously() // Load from disk cache synchronously for immediate display
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.5), radius: shadowRadius, x: 0, y: 0)
    }
}

// MARK: - Featured Amiibo Images
struct FeaturedAmiiboKingfisherImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(url: String, width: CGFloat = 140, height: CGFloat = 140, cornerRadius: CGFloat = 8, shadowRadius: CGFloat = 8) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                    )
            }
            .onFailure { _ in
                // Handle failure if needed
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.5), radius: shadowRadius, x: 0, y: 0)
    }
}

// MARK: - Series Grid Images
struct SeriesGridKingfisherImage: View {
    let url: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(url: String, width: CGFloat = 114, height: CGFloat = 114, cornerRadius: CGFloat = 8, shadowRadius: CGFloat = 8) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                    )
            }
            .onFailure { _ in
                // Handle failure if needed
            }
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.5), radius: shadowRadius, x: 0, y: 0)
    }
}
