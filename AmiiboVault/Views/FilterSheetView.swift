import SwiftUI

struct FilterSheetView: View {
    @ObservedObject var viewModel: AmiiboListViewModel
    let onClearAll: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var typeExpanded = false
    @State private var setExpanded = false
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var analyticsService = AnalyticsService.shared

    private var selectedType: String? { viewModel.selectedType }
    private var selectedSet: String? { viewModel.selectedSet }
    private var collectionCatalogFilter: CollectionCatalogFilter { viewModel.collectionCatalogFilter }

    private var hasActiveFilters: Bool {
        selectedType != nil || selectedSet != nil || collectionCatalogFilter != .all
    }

    private var sheetBackground: Color {
        themeManager.isDarkMode
            ? Color(red: 0.133, green: 0.133, blue: 0.145)
            : Color(red: 1.0, green: 0.984, blue: 0.996)
    }

    private var primaryText: Color {
        themeManager.isDarkMode ? .white : .black
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Filters")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(primaryText)
                        Spacer()
                        Button("Clear all") {
                            onClearAll()
                            dismiss()
                        }
                        .disabled(!hasActiveFilters)
                        .foregroundColor(hasActiveFilters ? .appRed : .gray)
                    }

                    if hasActiveFilters {
                        FlowLayout(spacing: 6) {
                            if collectionCatalogFilter != .all {
                                summaryChip(collectionCatalogFilter.label)
                            }
                            if let selectedType {
                                summaryChip(selectedType)
                            }
                            if let selectedSet {
                                summaryChip(selectedSet)
                            }
                        }
                    }

                    sectionLabel("Collection")

                    HStack(spacing: 8) {
                        ForEach(CollectionCatalogFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                viewModel.collectionCatalogFilter = filter
                                viewModel.applyCurrentFilters()
                                analyticsService.logEvent(
                                    AnalyticsService.AMIIBO_FILTER_NOT_COLLECTED,
                                    name: filter.rawValue
                                )
                            }) {
                                Text(filter.label)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .modifier(FilterChoicePillModifier(isSelected: collectionCatalogFilter == filter))
                            }
                        }
                    }

                    Divider()
                        .overlay(Color.gray.opacity(0.25))

                    expandableSection(title: "Type", expanded: $typeExpanded) {
                        filterPills(options: AmiiboFilters.types, selected: selectedType) { value in
                            viewModel.selectedType = value
                            viewModel.applyCurrentFilters()
                            analyticsService.logEvent(AnalyticsService.AMIIBO_FILTER_TYPE_SEARCH, name: value)
                        } onClear: {
                            viewModel.selectedType = nil
                            viewModel.applyCurrentFilters()
                        }
                    }

                    Divider()
                        .overlay(Color.gray.opacity(0.25))

                    expandableSection(title: "Set", expanded: $setExpanded) {
                        filterPills(options: AmiiboFilters.sets, selected: selectedSet) { value in
                            viewModel.selectedSet = value
                            viewModel.applyCurrentFilters()
                            analyticsService.logEvent(AnalyticsService.AMIIBO_FILTER_SET_SEARCH, name: value)
                        } onClear: {
                            viewModel.selectedSet = nil
                            viewModel.applyCurrentFilters()
                        }
                    }
                }
                .padding(20)
            }
            .background(sheetBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appRed)
                }
            }
        }
        .onAppear {
            typeExpanded = selectedType != nil
            setExpanded = selectedSet != nil
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(primaryText.opacity(0.85))
            .padding(.top, 4)
    }

    @ViewBuilder
    private func expandableSection<Content: View>(
        title: String,
        expanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { expanded.wrappedValue.toggle() }) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(primaryText.opacity(0.85))
                    Spacer()
                    Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            if expanded.wrappedValue {
                content()
            }
        }
    }

    @ViewBuilder
    private func filterPills(
        options: [String],
        selected: String?,
        onSelect: @escaping (String) -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        FlowLayout(spacing: 8) {
            Button("All") { onClear() }
                .buttonStyle(FilterPillStyle(isSelected: selected == nil))
            ForEach(options, id: \.self) { option in
                Button(option) { onSelect(option) }
                    .buttonStyle(FilterPillStyle(isSelected: selected == option))
            }
        }
    }

    private func summaryChip(_ label: String) -> some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.appRed)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

private struct FilterChoicePillModifier: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .foregroundColor(isSelected ? .white : .appRed)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.appRed : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appRed, lineWidth: isSelected ? 0 : 1)
            )
    }
}

private struct FilterPillStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : .appRed)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.appRed : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appRed, lineWidth: isSelected ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Simple flow layout for filter pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
