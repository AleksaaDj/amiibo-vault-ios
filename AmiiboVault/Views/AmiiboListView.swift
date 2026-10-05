import SwiftUI
import FirebaseAnalytics

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
    @State private var showingFilterSheet = false
    @State private var showingUpcoming = false
    @Binding var isDetailsPresented: Bool
    @State private var selectedAmiiboForDetails: Amiibo? = nil
    @State private var showingDetails = false
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var analyticsService = AnalyticsService.shared
    
    init(viewModel: AmiiboListViewModel = AmiiboListViewModel(), isDetailsPresented: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._isDetailsPresented = isDetailsPresented
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar - Fixed at top
            SearchBarView(searchText: $viewModel.searchText)
                .padding(.horizontal)
            
            // Featured Amiibo Card - Fixed (hidden in landscape mode to save space)
            if !orientationManager.isLandscape, let featuredAmiibo = viewModel.featuredAmiibo {
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
                showingFilterSheet: $showingFilterSheet,
                showingUpcoming: $showingUpcoming,
                isGridView: $viewModel.isGridView,
                selectedType: $viewModel.selectedType,
                selectedSet: $viewModel.selectedSet,
                activeFilterCount: viewModel.activeFilterCount,
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
                .onAppear {
                    // Trigger alert when error appears if not already shown
                    if !viewModel.showErrorAlert {
                        viewModel.errorAlertMessage = viewModel.errorMessage ?? "Error loading data"
                        viewModel.showErrorAlert = true
                    }
                }
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
            
            // Log screen view
            analyticsService.logScreenView("search_screen", screenClass: "AmiiboListView")
        }
        .alert("Error Loading Data", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
            Button("Retry") {
                viewModel.loadAmiibos()
            }
        } message: {
            Text(viewModel.errorAlertMessage)
        }
        .background(
            // Hidden NavigationLink that gets triggered by state
            Group {
                if let selectedAmiibo = selectedAmiiboForDetails {
                    // Suppress deprecation warning for NavigationLink
                    NavigationLink(
                        destination: AmiiboDetailsView(amiibo: selectedAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented, amiiboList: viewModel.filteredAmiiboList),
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
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheetView(
                viewModel: viewModel,
                onClearAll: {
                    viewModel.clearAllFilters()
                }
            )
        }
        .sheet(isPresented: $showingUpcoming) {
            UpcomingAmiiboListView()
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
    @Binding var showingFilterSheet: Bool
    @Binding var showingUpcoming: Bool
    @Binding var isGridView: Bool
    @Binding var selectedType: String?
    @Binding var selectedSet: String?
    let activeFilterCount: Int
    @ObservedObject var viewModel: AmiiboListViewModel
    let onToggleLayout: () -> Void
    @StateObject private var analyticsService = AnalyticsService.shared
    
    var body: some View {
        HStack {
            Button(action: {
                showingFilterSheet = true
                analyticsService.logEvent(AnalyticsService.AMIIBO_FILTER_TYPE_SEARCH, name: "filter_sheet_opened")
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 12))
                    Text(activeFilterCount > 0 ? "Filter (\(activeFilterCount))" : "Filter")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(activeFilterCount > 0 ? .white : .appRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(activeFilterCount > 0 ? Color.appRed : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appRed, lineWidth: activeFilterCount > 0 ? 0 : 1)
                )
            }

            Button(action: {
                showingSortOptions = true
                analyticsService.logEvent(AnalyticsService.AMIIBO_SORT_SEARCH, name: "sort_options_opened")
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12))
                    Text(sortType ?? "Sort")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.appRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appRed, lineWidth: 1)
                )
            }

            Spacer()

            Button(action: {
                showingUpcoming = true
                analyticsService.logEvent(AnalyticsService.AMIIBO_UPCOMING_OPENED, name: "upcoming_opened")
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("Upcoming")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.appRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.appRed, lineWidth: 1)
                )
            }

            Button(action: {
                onToggleLayout()
                let eventName = isGridView ? AnalyticsService.AMIIBO_LIST : AnalyticsService.AMIIBO_GRID
                analyticsService.logEvent(eventName, name: isGridView ? "list_view" : "grid_view")
            }) {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.appRed)
                    .font(.title2)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
    }
}

// MARK: - Sort Options View
struct SortOptionsView: View {
    @Binding var sortType: String?
    let onSortChanged: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyticsService = AnalyticsService.shared
    
    let sortOptions = AmiiboFilters.sortTypesSearch
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortOptions, id: \.self) { option in
                    Button(action: {
                        sortType = option
                        analyticsService.logEvent(AnalyticsService.AMIIBO_SORT_SEARCH, name: option)
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

#Preview {
    AmiiboListView()
}
