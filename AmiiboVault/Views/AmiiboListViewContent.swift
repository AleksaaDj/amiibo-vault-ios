import SwiftUI

// Suppress deprecation warning for NavigationLink - will be updated when migrating to NavigationStack

// MARK: - Amiibo List Content (Vertical List)
struct AmiiboListContent: View {
    let amiiboList: [Amiibo]
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @State private var selectedAmiiboForDetails: Amiibo? = nil
    @State private var showingDetails = false
    
    var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(amiiboList) { amiibo in
                Button(action: {
                    // Dismiss keyboard properly
                    dismissKeyboard()
                    
                    // Navigate immediately
                    selectedAmiiboForDetails = amiibo
                    showingDetails = true
                }) {
                    AmiiboListItemView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .background(
            // Hidden NavigationLink that gets triggered by state
            Group {
                if let selectedAmiibo = selectedAmiiboForDetails {
                    // Suppress deprecation warning for NavigationLink
                    NavigationLink(
                        destination: AmiiboDetailsView(amiibo: selectedAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented, amiiboList: amiiboList),
                        isActive: $showingDetails
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        )
    }
}

// MARK: - Amiibo Grid View (3-column grid)
struct AmiiboGridView: View {
    let amiiboList: [Amiibo]
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @State private var selectedAmiiboForDetails: Amiibo? = nil
    @State private var showingDetails = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(amiiboList) { amiibo in
                Button(action: {
                    // Dismiss keyboard properly
                    dismissKeyboard()
                    
                    // Navigate immediately
                    selectedAmiiboForDetails = amiibo
                    showingDetails = true
                }) {
                    AmiiboGridItemView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
        .background(
            // Hidden NavigationLink that gets triggered by state
            Group {
                if let selectedAmiibo = selectedAmiiboForDetails {
                    // Suppress deprecation warning for NavigationLink
                    NavigationLink(
                        destination: AmiiboDetailsView(amiibo: selectedAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented, amiiboList: amiiboList),
                        isActive: $showingDetails
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        )
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
                .cornerRadius(10)
                .opacity(0.1)
                        
            // Main content
            HStack(spacing: 4) {
                // Amiibo Image with white shadow
                AmiiboListKingfisherImage(url: amiibo.image, width: 76, height: 76, cornerRadius: 6, shadowRadius: 6)
                    .padding(.vertical, 5) // Add padding to show full shadow
                
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
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .padding(.trailing, 15)
            }
            .padding(.horizontal, 4)
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
        AmiiboGridKingfisherImage(url: amiibo.image, width: 110, height: 110, cornerRadius: 4, shadowRadius: 6, isDarkMode: themeManager.isDarkMode)
            .padding(.vertical, 5) // Add padding to show full shadow
    }
}

#Preview {
    let viewModel = AmiiboListViewModel()
    return AmiiboListContent(amiiboList: [], viewModel: viewModel, isDetailsPresented: .constant(false))
}
