import SwiftUI

struct GamesView: View {
    @Binding var isGameDetailsPresented: Bool
    @StateObject private var viewModel = GamesViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingSortOptions = false
    @State private var showingGenreOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.appRed)
                
                TextField("Search Games", text: $viewModel.searchText)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .accentColor(themeManager.isDarkMode ? .white : .black)
                    .placeholder(when: viewModel.searchText.isEmpty) {
                        Text("Search Games")
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .gray)
                    }
            }
            .padding()
            .background(Color.clear)
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Filter Controls
            GameFilterControlsView(
                selectedSortType: $viewModel.selectedSortType,
                selectedGenre: $viewModel.selectedGenre,
                availableGenres: viewModel.availableGenres,
                showingSortOptions: $showingSortOptions,
                showingGenreOptions: $showingGenreOptions,
                onSortTypeSelected: { sortType in
                    viewModel.selectSortType(sortType)
                },
                onSortTypeRemoved: {
                    viewModel.removeSortType()
                },
                onGenreSelected: { genre in
                    viewModel.selectGenre(genre)
                },
                onGenreRemoved: {
                    viewModel.removeGenre()
                }
            )
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            // Content
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if viewModel.filteredGames.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 60))
                        .foregroundColor(.appRed)
                    
                    Text("No games found")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    
                    Text("Try adjusting your search or filters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                GameListView(games: viewModel.filteredGames, isGameDetailsPresented: $isGameDetailsPresented)
            }
        }
            .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
            .onAppear {
                // Force refresh when screen appears
                viewModel.loadGames()
            }
            .sheet(isPresented: $showingSortOptions) {
                GameSortOptionsView(
                    sortOptions: viewModel.sortOptions,
                    selectedSortType: $viewModel.selectedSortType,
                    onSortTypeSelected: { sortType in
                        viewModel.selectSortType(sortType)
                        showingSortOptions = false
                    },
                    onRemoveSort: {
                        viewModel.removeSortType()
                        showingSortOptions = false
                    }
                )
            }
            .sheet(isPresented: $showingGenreOptions) {
                GenreOptionsView(
                    genres: viewModel.availableGenres,
                    selectedGenre: $viewModel.selectedGenre,
                    onGenreSelected: { genre in
                        viewModel.selectGenre(genre)
                        showingGenreOptions = false
                    },
                    onRemoveGenre: {
                        viewModel.removeGenre()
                        showingGenreOptions = false
                    }
                )
            }
        }
}

// MARK: - Game List View
struct GameListView: View {
    let games: [Game]
    @Binding var isGameDetailsPresented: Bool
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(games) { game in
                    NavigationLink(destination: GameDetailsView(game: game, isGameDetailsPresented: $isGameDetailsPresented)) {
                        GameListItemView(game: game)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 100) // Add bottom padding for custom navigation bar
        }
    }
}


// MARK: - Game List Item View
struct GameListItemView: View {
    let game: Game
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // Game Image - no padding on top, left, bottom
            AsyncImage(url: URL(string: game.backgroundImage ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 80, height: 80)
            .clipShape(
                LeftRoundedRectangle(cornerRadius: 8)
            )
            
            // Game Info
            VStack(alignment: .leading, spacing: 0) {
                // Title and release date at the top
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name ?? "Unknown Game")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .lineLimit(2)
                    
                    if let released = game.released {
                        Text(formatReleaseDate(released))
                            .font(.caption)
                            .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.7) : .secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                
                Spacer()
                
                // Rating and metacritic at the bottom
                HStack(spacing: 6) {
                    if let rating = game.rating {
                        HStack(spacing: 1) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.yellow.opacity(0.2))
                        .clipShape(Capsule())
                    }
                    
                    if let metacritic = game.metacritic {
                        HStack(spacing: 1) {
                            Image(systemName: "m.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10))
                            Text("\(metacritic)")
                                .font(.system(size: 10))
                                .fontWeight(.medium)
                                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
        }
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.isDarkMode ? Color.black : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func formatReleaseDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM dd, yyyy"
            return displayFormatter.string(from: date)
        }
        
        return dateString
    }
}


// MARK: - Game Filter Controls View
struct GameFilterControlsView: View {
    @Binding var selectedSortType: String?
    @Binding var selectedGenre: String?
    let availableGenres: [String]
    @Binding var showingSortOptions: Bool
    @Binding var showingGenreOptions: Bool
    let onSortTypeSelected: (String) -> Void
    let onSortTypeRemoved: () -> Void
    let onGenreSelected: (String) -> Void
    let onGenreRemoved: () -> Void
    
    var body: some View {
        HStack {
            // Sort Button
            Button(action: {
                showingSortOptions = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedSortType != nil ? .white : .red)
                    Text(selectedSortType ?? "Sort")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedSortType != nil ? .white : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSortType != nil ? Color.red : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: selectedSortType != nil ? 0 : 1)
                )
            }
            
            // Genre Button
            Button(action: {
                showingGenreOptions = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedGenre != nil ? .white : .red)
                    Text(selectedGenre ?? "Genre")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedGenre != nil ? .white : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedGenre != nil ? Color.red : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: selectedGenre != nil ? 0 : 1)
                )
            }
            
            Spacer()
        }
    }
}

// MARK: - Game Sort Options View
struct GameSortOptionsView: View {
    let sortOptions: [String]
    @Binding var selectedSortType: String?
    let onSortTypeSelected: (String) -> Void
    let onRemoveSort: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Button(action: onRemoveSort) {
                    HStack {
                        Text("Remove Sort")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                
                ForEach(sortOptions, id: \.self) { option in
                    Button(action: {
                        onSortTypeSelected(option)
                    }) {
                        HStack {
                            Text(option)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSortType == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appRed)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort Games")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Genre Options View
struct GenreOptionsView: View {
    let genres: [String]
    @Binding var selectedGenre: String?
    let onGenreSelected: (String) -> Void
    let onRemoveGenre: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Button(action: onRemoveGenre) {
                    HStack {
                        Text("Remove Filter")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
                
                ForEach(genres, id: \.self) { genre in
                    Button(action: {
                        onGenreSelected(genre)
                    }) {
                        HStack {
                            Text(genre)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedGenre == genre {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.appRed)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter by Genre")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Custom Shape for iOS 15.6 compatibility
struct LeftRoundedRectangle: Shape {
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        // Start from top-left corner
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top edge (right side is straight)
        path.addLine(to: CGPoint(x: width, y: 0))
        
        // Right edge (straight)
        path.addLine(to: CGPoint(x: width, y: height))
        
        // Bottom edge (right side is straight)
        path.addLine(to: CGPoint(x: cornerRadius, y: height))
        
        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: cornerRadius, y: height - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        // Top-left corner
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    GamesView(isGameDetailsPresented: .constant(false))
}
