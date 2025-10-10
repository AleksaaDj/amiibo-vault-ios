import SwiftUI

struct AmiiboSeriesView: View {
    let gameSeries: String
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmiibo: Amiibo?
    @State private var seriesAmiibos: [Amiibo] = []
    @State private var isLoading = true
    @StateObject private var themeManager = ThemeManager.shared
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Navigation Bar
            HStack {
                
                Spacer()
                
                Text(gameSeries)
                    .foregroundColor(.appRed)
                    .font(.headline)
                
                Spacer()
                
                // Empty space to balance the back button
                Color.clear
                    .frame(width: 24, height: 24)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                        .scaleEffect(1.5)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(seriesAmiibos) { amiibo in
                            AmiiboSeriesGridItem(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented, selectedAmiibo: $selectedAmiibo)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .onAppear {
            loadSeriesAmiibos()
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedAmiibo != nil },
            set: { if !$0 { selectedAmiibo = nil; isDetailsPresented = false } }
        )) {
            if let amiibo = selectedAmiibo {
                AmiiboDetailsView(amiibo: amiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
            }
        }
    }
    
    private func loadSeriesAmiibos() {
        // Filter amiibos by game series
        seriesAmiibos = viewModel.amiiboList.filter { $0.gameSeries == gameSeries }
        isLoading = false
    }
}

struct AmiiboSeriesGridItem: View {
    let amiibo: Amiibo
    let viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @Binding var selectedAmiibo: Amiibo?
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 5) {
            // Amiibo Image
            CachedAsyncImage(url: amiibo.image) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 114, height: 114)
                        .shadow(radius: 5, x: 0, y: 0)
                case .failure(_):
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 114, height: 114)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 114, height: 114)
                        .overlay(
                            ProgressView()
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 114, height: 114)
                }
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 114, height: 114)
                    .overlay(
                        ProgressView()
                    )
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedAmiibo = amiibo
                isDetailsPresented = true
            }
            
            // Character Name
            Text(amiibo.character)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 105)
        }
    }
}

#Preview {
    let viewModel = AmiiboListViewModel()
    return AmiiboSeriesView(gameSeries: "The Legend of Zelda", viewModel: viewModel, isDetailsPresented: .constant(false))
}
