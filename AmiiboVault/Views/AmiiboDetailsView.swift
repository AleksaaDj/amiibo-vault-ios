import SwiftUI

struct AmiiboDetailsView: View {
    let amiibo: Amiibo
    @ObservedObject var viewModel: AmiiboListViewModel
    @Binding var isDetailsPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showingSeriesView = false
    @State private var showingCompatibilityView = false
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var adMobService = AdMobService.shared
    
    // Get the updated amiibo data from the view model
    private var currentAmiibo: Amiibo {
        viewModel.filteredAmiiboList.first { $0.head == amiibo.head && $0.tail == amiibo.tail } ?? amiibo
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Amiibo Image
                CachedAsyncImage(url: currentAmiibo.image) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                    case .failure(_):
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.gray)
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)
                            .overlay(
                                ProgressView()
                            )
                    @unknown default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: 200, height: 200)
                    }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 200, height: 200)
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
                
                // Amiibo Name - Centered
                Text(currentAmiibo.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 80)
                
                // Details Section
                VStack(spacing: 0) {
                    // Character
                    DetailRow(label: "Character", value: currentAmiibo.character)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Game Series
                    DetailRow(label: "Game Series", value: currentAmiibo.gameSeries)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Set
                    DetailRow(label: "Set", value: currentAmiibo.amiiboSeries)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Type
                    DetailRow(label: "Type", value: currentAmiibo.type)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Serial
                    DetailRow(label: "Serial", value: currentAmiibo.head + currentAmiibo.tail)
                }
                .padding(.horizontal, 60)
                
                // Action Buttons
                VStack(spacing: 0) {
                    // More from series button
                    Button(action: {
                        showingSeriesView = true
                    }) {
                        Text("more from series")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 70)
                    
                    // Compatibility and usage button
                    Button(action: {
                        showingCompatibilityView = true
                    }) {
                        Text("compatibility and usage")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(themeManager.isDarkMode ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 80)
                    
                    // Add to collection button
                    Button(action: {
                        if currentAmiibo.isInCollection {
                            viewModel.removeFromCollection(currentAmiibo)
                        } else {
                            viewModel.addToCollection(currentAmiibo)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: currentAmiibo.isInCollection ? "minus.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                            Text(currentAmiibo.isInCollection ? "remove from my collection" : "add to my collection")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.red)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 85)
                }
                
                // Release Info
                if let release = currentAmiibo.release {
                    ReleaseInfoView(release: release)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    openAmazonLink(for: currentAmiibo)
                }) {
                    Image(systemName: "cart")
                        .foregroundColor(.appRed)
                        .font(.system(size: 16, weight: .medium))
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.toggleWishlist(currentAmiibo)
                }) {
                    Image(systemName: currentAmiibo.isInWishlist ? "bookmark.fill" : "bookmark")
                        .foregroundColor(.appRed)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .background(themeManager.isDarkMode ? Color(red: 0.133, green: 0.133, blue: 0.145) : Color(red: 1.0, green: 0.984, blue: 0.996))
        .onTapGesture {
            // Dismiss keyboard when tapping anywhere on the details screen
            dismissKeyboard()
        }
        .onAppear {
            isDetailsPresented = true
        }
        .onDisappear {
            isDetailsPresented = false
        }
        .sheet(isPresented: $showingSeriesView) {
            AmiiboSeriesView(gameSeries: currentAmiibo.gameSeries, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
        }
        .fullScreenCover(isPresented: $showingCompatibilityView) {
            AmiiboCompatibilityView(amiibo: currentAmiibo, viewModel: viewModel, isDetailsPresented: $isDetailsPresented)
        }
        .onAppear {
            // Show interstitial ad (every 3rd time)
            adMobService.showInterstitialAd {
                // Ad dismissed or not shown
            }
        }
    }
    
    private func openAmazonLink(for amiibo: Amiibo) {
        // Create Amazon search URL like Android implementation
        let amiiboName = amiibo.name.replacingOccurrences(of: "&", with: " ")
        let amiiboNameFiltered = amiiboName.replacingOccurrences(of: " ", with: "+")
        let amiiboType = amiibo.type
        let amiiboSeries = amiibo.gameSeries.replacingOccurrences(of: " ", with: "+")
        
        let amazonURL = "https://www.amazon.com/s?k=\(amiiboNameFiltered)+Amiibo+\(amiiboType)+\(amiiboSeries)&tag=amiibovault-20"
        
        if let url = URL(string: amazonURL) {
            UIApplication.shared.open(url)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 2)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(themeManager.isDarkMode ? .white : .black)
                .lineLimit(1)
                .padding(.leading, 5)
        }
        .padding(.vertical, 7)
    }
}

struct ReleaseInfoView: View {
    let release: Release
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Spacer()
            if let au = release.au, !au.isEmpty, au != "null" {
                ReleaseCard(date: au, flag: "au_flag")
            }
            
            if let eu = release.eu, !eu.isEmpty, eu != "null" {
                ReleaseCard(date: eu, flag: "eu_flag")
            }
            
            if let jp = release.jp, !jp.isEmpty, jp != "null" {
                ReleaseCard(date: jp, flag: "jp_flag")
            }
            
            if let na = release.na, !na.isEmpty, na != "null" {
                ReleaseCard(date: na, flag: "us_flag")
            }
            Spacer()
        }
    }
}

struct ReleaseCard: View {
    let date: String
    let flag: String
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: -7) {
            // Flag circle
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 35, height: 35)
                    .shadow(radius: 5)
                
                // Flag image
                Image(flag)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 35, height: 35)
                    .clipShape(Circle())
            }
            
            // Date parts
            VStack(spacing: 0) {
                Text(dayAndMonth(from: date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
                    .padding(.top, 12)
                
                Text(year(from: date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.isDarkMode ? .white : .black)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func dayAndMonth(from dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: dateString) {
            let dayMonthFormatter = DateFormatter()
            dayMonthFormatter.dateFormat = "dd MMM"
            dayMonthFormatter.locale = Locale(identifier: "en_US_POSIX")
            return dayMonthFormatter.string(from: date)
        }
        
        // Fallback: try to parse manually
        let components = dateString.components(separatedBy: "-")
        if components.count == 3 {
            // Assume components are in the order: year, month, day
            return "\(components[2]) \(components[1])"
        }
        return dateString
    }

    private func year(from dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = inputFormatter.date(from: dateString) {
            let yearFormatter = DateFormatter()
            yearFormatter.dateFormat = "yyyy"
            yearFormatter.locale = Locale(identifier: "en_US_POSIX")
            return yearFormatter.string(from: date)
        }
        
        // Fallback: try to parse manually
        let components = dateString.components(separatedBy: "-")
        if components.count == 3 {
            return components[0] // Assume the first component is the year
        }
        return ""
    }
}
