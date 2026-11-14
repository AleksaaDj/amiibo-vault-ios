import SwiftUI
import UIKit

struct FeaturedAmiiboCard: View {
    let featuredAmiibo: Amiibo?
    @State private var cardColor = Color.yellow
    
    var body: some View {
        if let amiibo = featuredAmiibo {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(cardColor)
                    .frame(height: 90)
                    .shadow(color: cardColor.opacity(0.85), radius: 6)
                    .offset(y: 15)
                
                HStack {
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
                    
                    FeaturedAmiiboKingfisherImage(
                        url: amiibo.image,
                        width: 140,
                        height: 140,
                        cornerRadius: 8,
                        shadowRadius: 8,
                        onImageLoaded: { image in
                            if let uiColor = image.averageColor {
                                cardColor = Color(uiColor)
                            }
                        }
                    )
                    .offset(x: 15)
                }
                .padding(.horizontal, 20)
            }
            .contentShape(Rectangle())
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
        )
    )
    .padding()
}
