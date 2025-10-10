import SwiftUI

struct AvatarHelper {
    static func getAvatarImage(avatarId: Int?) -> String {
        guard let avatarId = avatarId else { 
            return "avatar_placeholder" 
        }
        
        switch avatarId {
        case 0: return "avatar_placeholder"  // PLACEHOLDER
        case 1: return "link_avatar"      // LINK
        case 2: return "peach_avatar"     // PEACH
        case 3: return "mario_avatar"     // MARIO
        case 4: return "alex_avatar"      // ALEX
        case 5: return "bokoblin_avatar"  // BOKOBLIN
        case 6: return "bowser_avatar"    // BOWSER
        case 7: return "inkling_avatar"   // INKLING
        case 8: return "isabelle_avatar"  // ISABELLE
        case 9: return "kirby_avatar"     // KIRBY
        case 10: return "lucina_avatar"   // LUCINA
        case 11: return "nabiru_avatar"   // NABIRU
        case 12: return "pikachu_avatar"  // PIKACHU
        case 13: return "samus_avatar"    // SAMUS
        case 14: return "yoshi_avatar"    // YOSHI
        default: return "avatar_placeholder"
        }
    }
    
    static func getAvatarColor(backgroundColorIndex: Int?) -> Color {
        guard let backgroundColorIndex = backgroundColorIndex else { 
            return .gray 
        }
        
        switch backgroundColorIndex {
        case 1: return Color(hex: "#EF5350") // RED_INDEX - Red
        case 2: return Color(hex: "#D57CE4") // PINK_INDEX - Pink
        case 3: return Color(hex: "#29B6F6") // BLUE_INDEX - Blue
        case 4: return Color(hex: "#121212") // BLACK_INDEX - Black
        case 5: return Color(hex: "#C5FDD835") // YELLOW_INDEX - Yellow
        case 6: return Color(hex: "#602E6A") // PURPLE_INDEX - Purple
        case 7: return Color(hex: "#26A69A") // TEAL_INDEX - Teal
        case 8: return Color(hex: "#808000") // OLIVE_INDEX - Olive
        case 9: return Color(hex: "#5B5B5B") // GREY_INDEX - Grey
        case 10: return Color(hex: "#66BB6A") // GREEN_INDEX - Green
        default: return .gray
        }
    }
    
    static func getRainbowGradient() -> LinearGradient {
        LinearGradient(
            colors: [
                Color.red, Color.orange, Color.yellow, Color.green,
                Color.blue, Color.purple, Color.pink
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}