import SwiftUI

// MARK: - Amiibo List Content (Vertical List)
struct AmiiboListContent: View {
    let amiiboList: [Amiibo]
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    
    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(amiiboList) { amiibo in
                NavigationLink(destination: AmiiboDetailsView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)) {
                    AmiiboListItemView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Amiibo Grid View (3-column grid)
struct AmiiboGridView: View {
    let amiiboList: [Amiibo]
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(amiiboList) { amiibo in
                NavigationLink(destination: AmiiboDetailsView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)) {
                    AmiiboGridItemView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Amiibo List Item View
struct AmiiboListItemView: View {
    let amiibo: Amiibo
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background color behind the image
            Color.gray // Replace with desired color
                .frame(width: 88) // Adjust width and height as needed
                .cornerRadius(8)
                .opacity(0.1)
                        
            // Main content
            HStack(spacing: 4) {
                // Amiibo Image with white shadow
                CachedAsyncImage(url: amiibo.image) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .shadow(radius: 5, x: 0, y: 0)
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.gray)
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                            .overlay(
                                ProgressView()
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 80, height: 80)
                    }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            ProgressView()
                        )
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(amiibo.name)
                            .font(.headline)
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            .lineLimit(2)
                        
                        Text(amiibo.gameSeries)
                            .font(.subheadline)
                            .foregroundColor(themeManager.isDarkMode ? .white : .secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer(minLength: 8)
                    
                    if let release = amiibo.release?.jp, !release.isEmpty, release != "null" {
                        Text(release)
                            .font(.caption)
                            .foregroundColor(themeManager.isDarkMode ? .white : .secondary)
                            .lineLimit(1)
                            .padding(.bottom, 4)
                    } else if let release = amiibo.release?.na, !release.isEmpty, release != "null" {
                        Text(release)
                            .font(.caption)
                            .foregroundColor(themeManager.isDarkMode ? .white : .secondary)
                            .lineLimit(1)
                            .padding(.bottom, 4)
                    } else if let release = amiibo.release?.eu, !release.isEmpty, release != "null" {
                        Text(release)
                            .font(.caption)
                            .foregroundColor(themeManager.isDarkMode ? .white : .secondary)
                            .lineLimit(1)
                            .padding(.bottom, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.trailing, 15)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .padding(.trailing, 40) // Exclude wishlist button area
            
            // Wishlist Button - top right corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        viewModel.toggleWishlist(amiibo)
                    }) {
                        Image(systemName: amiibo.isInWishlist ? "bookmark.fill" : "bookmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 20) // Adjust the height as needed
                            .foregroundColor(.appRed)
                    }
                    .padding(.trailing, 8)
                    .allowsHitTesting(true)
                }
                Spacer()
            }
            .padding(.top, 8)
            .allowsHitTesting(true)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.isDarkMode ? Color.black : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Amiibo Grid Item View
struct AmiiboGridItemView: View {
    let amiibo: Amiibo
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        // Just the image - no text, no wishlist icon, like Android
        CachedAsyncImage(url: amiibo.image) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110, height: 110)
                    .shadow(radius: 4, x: 0, y: 0)
                    .padding(5)
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.133) : Color.white)
                            .frame(width: 110, height: 110)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.gray)
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.133) : Color.white)
                            .frame(width: 110, height: 110)
                            .overlay(
                                ProgressView()
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.133) : Color.white)
                            .frame(width: 110, height: 110)
            }
        } placeholder: {
            RoundedRectangle(cornerRadius: 4)
                .fill(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.133) : Color.white)
                .frame(width: 110, height: 110)
                .overlay(
                    ProgressView()
                )
        }
    }
}

#Preview {
    let viewModel = AmiiboListViewModel()
    return AmiiboListContent(amiiboList: [], viewModel: viewModel, isDetailsPresented: .constant(false))
}
