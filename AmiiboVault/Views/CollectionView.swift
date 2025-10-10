import SwiftUI

struct CollectionView: View {
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    @State private var selectedTab = 0
    @State private var selectedType: String?
    @State private var selectedSet: String?
    @State private var selectedSort: String?
    
    private let tabs = ["my collection", "wishlist"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar with Theme Toggle
            HStack {
                Text("Collections")
                    .font(.title2)
                    .fontWeight(.regular)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                
                Spacer()
                
                Button(action: {
                    themeManager.toggleTheme()
                }) {
                    Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                        .font(.title2)
                        .foregroundColor(.appRed)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            // Statistics Info Card
            StatisticsInfoCard(
                selectedTab: selectedTab,
                collectionCount: currentAmiiboList.count,
                worldwideCount: getWorldwideCountForCurrentFilters(),
                isDarkMode: themeManager.isDarkMode
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Tab Selector
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = index
                            clearFilters()
                        }
                    }) {
                        Text(tabs[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTab == index ? .white : .appRed)
                            .frame(maxWidth: .infinity)
                            .frame(height: 35)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == index ? Color.appRed : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appRed, lineWidth: selectedTab == index ? 0 : 1.5)
                            )
                            .shadow(
                                color: selectedTab == index ? Color.appRed.opacity(0.3) : Color.clear,
                                radius: selectedTab == index ? 4 : 0,
                                x: 0,
                                y: selectedTab == index ? 2 : 0
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Filter Controls
            CollectionFilterControlsView(
                selectedType: $selectedType,
                selectedSet: $selectedSet,
                selectedSort: $selectedSort
            )
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Divider
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.top, 10)
            
            // Amiibo Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    ForEach(currentAmiiboList) { amiibo in
                        CollectionGridItem(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .onAppear {
            // Refresh collection and wishlist data when screen appears
            viewModel.refreshCollectionAndWishlist()
        }
    }
    
    private var currentAmiiboList: [Amiibo] {
        let baseList = selectedTab == 0 ? viewModel.collectionAmiibos : viewModel.wishlistAmiibos
        
        var filteredList = baseList
        
        // Apply type filter
        if let type = selectedType {
            filteredList = filteredList.filter { $0.type == type }
        }
        
        // Apply set filter
        if let set = selectedSet {
            filteredList = filteredList.filter { $0.amiiboSeries == set }
        }
        
        // Apply sort
        if let sort = selectedSort {
            switch sort {
            case "Name A-Z":
                filteredList = filteredList.sorted { $0.name < $1.name }
            case "Name Z-A":
                filteredList = filteredList.sorted { $0.name > $1.name }
            case "Series A-Z":
                filteredList = filteredList.sorted { $0.gameSeries < $1.gameSeries }
            case "Series Z-A":
                filteredList = filteredList.sorted { $0.gameSeries > $1.gameSeries }
            case "Character A-Z":
                filteredList = filteredList.sorted { $0.character < $1.character }
            case "Character Z-A":
                filteredList = filteredList.sorted { $0.character > $1.character }
            default:
                break
            }
        }
        
        return filteredList
    }
    
    private func clearFilters() {
        selectedType = nil
        selectedSet = nil
        selectedSort = nil
    }
    
    private func getWorldwideCountForCurrentFilters() -> Int {
        // Get all amiibos from the main list
        let allAmiibos = viewModel.amiiboList
        
        // Apply the same filters as currentAmiiboList but to all amiibos
        var filteredList = allAmiibos
        
        // Apply type filter
        if let type = selectedType {
            filteredList = filteredList.filter { $0.type == type }
        }
        
        // Apply set filter
        if let set = selectedSet {
            filteredList = filteredList.filter { $0.amiiboSeries == set }
        }
        
        return filteredList.count
    }
}

struct StatisticsInfoCard: View {
    let selectedTab: Int
    let collectionCount: Int
    let worldwideCount: Int
    let isDarkMode: Bool
    
    private var progress: Double {
        guard worldwideCount > 0 else { return 0 }
        return Double(collectionCount) / Double(worldwideCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(collectionCount) amiibo in \(selectedTab == 0 ? "collection" : "wishlist")")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .padding(.bottom, 5)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)
            .padding(.bottom, 5)
            
            Text("\(worldwideCount) worldwide")
                .font(.system(size: 13))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isDarkMode ? Color(red: 0.4, green: 0.647, blue: 0.412) : Color(red: 0.533, green: 0.855, blue: 0.545)) // Dark: #66A569, Light: #88DA8B
        )
    }
}

struct CollectionGridItem: View {
    let amiibo: Amiibo
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationLink(destination: AmiiboDetailsView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)) {
            VStack(spacing: 8) {
                CachedAsyncImage(url: amiibo.image) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 114, height: 114)
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 114, height: 114)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.gray)
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 114, height: 114)
                            .overlay(
                                ProgressView()
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 114, height: 114)
                    }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 114, height: 114)
                        .overlay(
                            ProgressView()
                        )
                }
                .contentShape(Rectangle())
                
                Text(amiibo.character)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CollectionFilterControlsView: View {
    @Binding var selectedType: String?
    @Binding var selectedSet: String?
    @Binding var selectedSort: String?
    @State private var showingTypeOptions = false
    @State private var showingSetOptions = false
    @State private var showingSortOptions = false
    
    var body: some View {
        HStack {
            // Type Filter Button
            Button(action: {
                showingTypeOptions = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedType != nil ? .white : .red)
                    Text(selectedType ?? "Type")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedType != nil ? .white : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType != nil ? Color.red : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: selectedType != nil ? 0 : 1)
                )
            }
            
            // Set Filter Button
            Button(action: {
                showingSetOptions = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedSet != nil ? .white : .red)
                    Text(selectedSet ?? "Set")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedSet != nil ? .white : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSet != nil ? Color.red : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: selectedSet != nil ? 0 : 1)
                )
            }
            
            // Sort Button
            Button(action: {
                showingSortOptions = true
            }) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.red)
                    Text(selectedSort ?? "Sort")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showingTypeOptions) {
            CollectionTypeFilterView(selectedType: $selectedType)
        }
        .sheet(isPresented: $showingSetOptions) {
            CollectionSetFilterView(selectedSet: $selectedSet)
        }
        .sheet(isPresented: $showingSortOptions) {
            CollectionSortFilterView(selectedSort: $selectedSort)
        }
    }
}

struct CollectionTypeFilterView: View {
    @Binding var selectedType: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("Remove Filter") {
                    selectedType = nil
                    dismiss()
                }
                .foregroundColor(.red)
                
                ForEach(AmiiboFilters.types, id: \.self) { type in
                    Button(action: {
                        selectedType = type
                        dismiss()
                    }) {
                        HStack {
                            Text(type)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CollectionSetFilterView: View {
    @Binding var selectedSet: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("Remove Filter") {
                    selectedSet = nil
                    dismiss()
                }
                .foregroundColor(.red)
                
                ForEach(AmiiboFilters.sets, id: \.self) { set in
                    Button(action: {
                        selectedSet = set
                        dismiss()
                    }) {
                        HStack {
                            Text(set)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSet == set {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CollectionSortFilterView: View {
    @Binding var selectedSort: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Button("Clear Sort") {
                    selectedSort = nil
                    dismiss()
                }
                .foregroundColor(.red)
                
                ForEach(AmiiboFilters.sortTypes, id: \.self) { sort in
                    Button(action: {
                        selectedSort = sort
                        dismiss()
                    }) {
                        HStack {
                            Text(sort)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedSort == sort {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let viewModel = AmiiboListViewModel()
    return CollectionView(viewModel: viewModel, isDetailsPresented: .constant(false))
}
