import SwiftUI
import Kingfisher

struct UpcomingAmiiboListView: View {
    @StateObject private var viewModel = UpcomingAmiiboViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var analyticsService = AnalyticsService.shared
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .foregroundColor(.appRed)
                } else if viewModel.items.isEmpty {
                    Text("No upcoming amiibo right now. Check back soon!")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(32)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(viewModel.items) { item in
                                NavigationLink(destination: UpcomingAmiiboDetailView(item: item)) {
                                    UpcomingAmiiboGridItemView(item: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .simultaneousGesture(TapGesture().onEnded {
                                    analyticsService.logEvent(
                                        AnalyticsService.AMIIBO_UPCOMING_DETAIL,
                                        id: item.id,
                                        name: item.name
                                    )
                                })
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 48)
                    }
                }
            }
            .navigationTitle("Upcoming amiibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.appRed)
                    }
                }
            }
            .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        }
        .onAppear {
            viewModel.loadUpcoming()
        }
    }
}

struct UpcomingAmiiboGridItemView: View {
    let item: UpcomingAmiibo
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(spacing: 5) {
            KFImage(URL(string: item.image))
                .placeholder {
                    ProgressView()
                }
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)

            Text(item.name)
                .font(.caption)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)

            if !item.releaseDate.isEmpty {
                Text(item.releaseDate)
                    .font(.caption2)
                    .foregroundColor(themeManager.isDarkMode ? .white.opacity(0.85) : .black.opacity(0.75))
                    .lineLimit(1)
            }
        }
    }
}

struct UpcomingAmiiboDetailView: View {
    let item: UpcomingAmiibo
    @StateObject private var themeManager = ThemeManager.shared

    private var screenBackground: Color {
        themeManager.isDarkMode
            ? Color(red: 0.133, green: 0.133, blue: 0.145)
            : Color(red: 1.0, green: 0.984, blue: 0.996)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AmiiboDetailsKingfisherImage(
                    url: item.image,
                    width: 200,
                    height: 200,
                    cornerRadius: 8,
                    shadowRadius: 10
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 20) {
                    Text(item.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(themeManager.isDarkMode ? .white : .black)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 80)

                    VStack(spacing: 0) {
                        if !item.series.isEmpty {
                            DetailRow(label: "Set", value: item.series)
                            Divider()
                                .background(Color.gray.opacity(0.3))
                        }
                        if !item.type.isEmpty {
                            DetailRow(label: "Type", value: item.type)
                            Divider()
                                .background(Color.gray.opacity(0.3))
                        }
                        if !item.releaseDate.isEmpty {
                            DetailRow(label: "Release date", value: item.releaseDate)
                        }
                    }
                    .padding(.horizontal, 60)

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.system(size: 15))
                            .foregroundColor(themeManager.isDarkMode ? .white : .black)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 60)
                            .padding(.top, 4)
                    }

                    if let url = URL(string: item.sourceUrl), !item.sourceUrl.isEmpty {
                        Link(destination: url) {
                            Text("View on Nintendo.com")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 70)
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbarBackground(screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(screenBackground)
    }
}
