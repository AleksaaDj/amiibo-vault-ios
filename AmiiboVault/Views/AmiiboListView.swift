import SwiftUI

// Suppress deprecation warning for NavigationLink - will be updated when migrating to NavigationStack

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

struct AmiiboListView: View {
    @ObservedObject var viewModel: AmiiboListViewModel
    @State private var showingSortOptions = false
    @Binding var isDetailsPresented: Bool
    @State private var selectedAmiiboForDetails: Amiibo? = nil
    @State private var showingDetails = false
    @StateObject private var themeManager = ThemeManager.shared
    
    init(viewModel: AmiiboListViewModel = AmiiboListViewModel(), isDetailsPresented: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._isDetailsPresented = isDetailsPresented
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar - Fixed at top
            SearchBarView(searchText: $viewModel.searchText)
                .padding(.horizontal)
            
            // Featured Amiibo Card - Fixed
            if let featuredAmiibo = viewModel.featuredAmiibo {
                Button(action: {
                    // Dismiss keyboard properly
                    dismissKeyboard()
                    
                    // Navigate immediately
                    selectedAmiiboForDetails = featuredAmiibo
                    showingDetails = true
                }) {
                    FeaturedAmiiboCard(featuredAmiibo: featuredAmiibo)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
            }
            
            // Filter and Sort Controls - Fixed
            FilterControlsView(
                sortType: $viewModel.sortType,
                showingSortOptions: $showingSortOptions,
                isGridView: $viewModel.isGridView,
                selectedType: $viewModel.selectedType,
                selectedSet: $viewModel.selectedSet,
                viewModel: viewModel,
                onToggleLayout: {
                    viewModel.toggleGridView()
                }
            )
            .padding(.horizontal)
            .padding(.top, 6)
            
            Divider()
                .padding(.vertical, 8)
            
            // Content - Only this part scrolls
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading Amiibo...")
                    .foregroundColor(.red)
                Spacer()
            } else if viewModel.errorMessage != nil {
                Spacer()
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    Text(viewModel.errorMessage ?? "Error loading data")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        viewModel.loadAmiibos()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
                Spacer()
            } else if viewModel.filteredAmiiboList.isEmpty {
                Spacer()
                VStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No Amiibo found")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                // Amiibo List/Grid - Only this part is scrollable
                if viewModel.isGridView {
                    ScrollView {
                        AmiiboGridView(amiiboList: viewModel.filteredAmiiboList, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                    }
                } else {
                    // List View - Vertical List
                    ScrollView {
                        AmiiboListContent(amiiboList: viewModel.filteredAmiiboList, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
                    }
                }
            }
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .onAppear {
            // Always try to load featured Amiibo on appear
            viewModel.loadFeaturedAmiiboFromDatabase()
        }
        .background(
            // Hidden NavigationLink that gets triggered by state
            Group {
                if let selectedAmiibo = selectedAmiiboForDetails {
                    // Suppress deprecation warning for NavigationLink
                    NavigationLink(
                        destination: AmiiboDetailsView(amiibo: selectedAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented),
                        isActive: $showingDetails
                    ) {
                        EmptyView()
                    }
                    .hidden()
                }
            }
        )
        .sheet(isPresented: $showingSortOptions) {
            SortOptionsView(sortType: $viewModel.sortType, onSortChanged: { newSortType in
                viewModel.setSortType(newSortType)
            })
        }
    }
}

// MARK: - Search Bar View
struct SearchBarView: View {
    @Binding var searchText: String
    let placeholder: String
    @StateObject private var themeManager = ThemeManager.shared
    @FocusState private var isTextFieldFocused: Bool
    
    
    init(searchText: Binding<String>, placeholder: String = "Search Amiibo") {
        self._searchText = searchText
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appRed)
            
            TextField(placeholder, text: $searchText)
                .focused($isTextFieldFocused)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .accentColor(themeManager.isDarkMode ? .white : .black)
                .placeholder(when: searchText.isEmpty) {
                    Text(placeholder)
                        .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.6) : .gray)
                }
        }
        .padding()
        .background(Color.clear)
        .cornerRadius(10)
        .onAppear {
            // Dismiss focus when view appears (e.g., when returning from details)
            isTextFieldFocused = false
        }
    }
}

// MARK: - Filter Controls View
struct FilterControlsView: View {
    @Binding var sortType: String?
    @Binding var showingSortOptions: Bool
    @Binding var isGridView: Bool
    @Binding var selectedType: String?
    @Binding var selectedSet: String?
    @State private var showingTypeOptions = false
    @State private var showingSetOptions = false
    @ObservedObject var viewModel: AmiiboListViewModel
    let onToggleLayout: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            // Type Filter Button
            Button(action: {
                showingTypeOptions = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "tag")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedType != nil ? .white : .appRed)
                    Text(selectedType ?? "Type")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedType != nil ? .white : .appRed)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedType != nil ? Color.appRed : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appRed, lineWidth: selectedType != nil ? 0 : 1)
                )
            }
            
            // Set Filter Button
            Button(action: {
                showingSetOptions = true
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedSet != nil ? .white : .appRed)
                    Text(selectedSet ?? "Set")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(selectedSet != nil ? .white : .appRed)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedSet != nil ? Color.appRed : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appRed, lineWidth: selectedSet != nil ? 0 : 1)
                )
            }
            
            // Sort Button
            Button(action: {
                showingSortOptions = true
            }) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.appRed)
                    Text(sortType ?? "Sort")
                        .font(.caption)
                        .foregroundColor(.appRed)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            
            Spacer()
            
            // Layout Toggle Button
            Button(action: onToggleLayout) {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.appRed)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .sheet(isPresented: $showingTypeOptions) {
            TypeFilterView(selectedType: $selectedType, viewModel: viewModel)
        }
        .sheet(isPresented: $showingSetOptions) {
            SetFilterView(selectedSet: $selectedSet, viewModel: viewModel)
        }
    }
}

// MARK: - Sort Options View
struct SortOptionsView: View {
    @Binding var sortType: String?
    let onSortChanged: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    let sortOptions = [
        "Name A-Z",
        "Name Z-A",
        "Series A-Z",
        "Series Z-A",
        "Character A-Z",
        "Character Z-A",
        "Release Date (Newest)",
        "Release Date (Oldest)"
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortOptions, id: \.self) { option in
                    Button(action: {
                        sortType = option
                        onSortChanged(option)
                        dismiss()
                    }) {
                        HStack {
                            Text(option)
                            Spacer()
                            if sortType == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Button("Clear Sort") {
                    sortType = nil
                    onSortChanged(nil)
                    dismiss()
                }
                .foregroundColor(.red)
            }
            .navigationTitle("Sort Options")
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

// MARK: - Type Filter View
struct TypeFilterView: View {
    @Binding var selectedType: String?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AmiiboListViewModel
    
    init(selectedType: Binding<String?>, viewModel: AmiiboListViewModel = AmiiboListViewModel()) {
        self._selectedType = selectedType
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationView {
            List {
                Button("Remove Filter") {
                    viewModel.removeTypeFilter()
                    dismiss()
                }
                .foregroundColor(.red)
                
                ForEach(AmiiboFilters.types, id: \.self) { type in
                    Button(action: {
                        viewModel.setTypeFilter(type)
                        dismiss()
                    }) {
                        HStack {
                            Text(type)
                            Spacer()
                            if selectedType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Filter by Type")
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

// MARK: - Set Filter View
struct SetFilterView: View {
    @Binding var selectedSet: String?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AmiiboListViewModel
    
    init(selectedSet: Binding<String?>, viewModel: AmiiboListViewModel = AmiiboListViewModel()) {
        self._selectedSet = selectedSet
        self.viewModel = viewModel
    }
    
    var body: some View {
        NavigationView {
            List {
                Button("Remove Filter") {
                    viewModel.removeSetFilter()
                    dismiss()
                }
                .foregroundColor(.red)
                
                ForEach(AmiiboFilters.sets, id: \.self) { set in
                    Button(action: {
                        viewModel.setSetFilter(set)
                        dismiss()
                    }) {
                        HStack {
                            Text(set)
                            Spacer()
                            if selectedSet == set {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Filter by Set")
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
    AmiiboListView()
}
