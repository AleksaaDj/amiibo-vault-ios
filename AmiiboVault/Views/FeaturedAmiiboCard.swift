import SwiftUI

struct FeaturedAmiiboCard: View {
    let featuredAmiibo: Amiibo?
    let onTap: (Amiibo) -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        if let amiibo = featuredAmiibo {
            ZStack {
                // Background card with yellow color
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow)
                    .frame(height: 90)
                    .shadow(color: Color.yellow, radius: 6)
                    .offset(y: 15) // Offset to match Android design
                
                HStack {
                    // Left side - Text content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Featured amiibo")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.black)
                        
                        Text(amiibo.character)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(amiibo.gameSeries)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white)
                    }
                    .padding(.leading, 4)
                    .padding(.top, 25)
                    
                    Spacer()
                    
                    // Right side - Amiibo image (extends beyond card edges)
                    CachedAsyncImage(url: amiibo.image) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140, height: 140)
                        case .failure(_):
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .frame(width: 140, height: 140)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.gray)
                                )
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .frame(width: 140, height: 140)
                                .overlay(
                                    ProgressView()
                                )
                        @unknown default:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .frame(width: 140, height: 140)
                        }
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                            .frame(width: 140, height: 140)
                            .overlay(
                                ProgressView()
                            )
                    }
                    .offset(x: 15) // Extend more over top edge
                }
                .padding(.horizontal, 20)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap(amiibo)
            }
        }
    }
}

#Preview {
    FeaturedAmiiboCard(
        featuredAmiibo: Amiibo(
            amiiboSeries: "Super Smash Bros.",
            character: "Mario",
            gameSeries: "Super Mario",
            head: "00000000",
            image: "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_00000000-00020000.png",
            name: "Mario",
            tail: "00020000",
            type: "Figure",
            featured: true,
            color: 0xFF6B6B6B
        ),
        onTap: { _ in }
    )
    .padding()
}
