import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let darkModeKey = "isDarkMode"
    
    private init() {
        // Load saved theme preference
        self.isDarkMode = userDefaults.bool(forKey: darkModeKey)
    }
    
    func toggleTheme() {
        isDarkMode.toggle()
        userDefaults.set(isDarkMode, forKey: darkModeKey)
    }
    
    func setTheme(_ isDark: Bool) {
        isDarkMode = isDark
        userDefaults.set(isDarkMode, forKey: darkModeKey)
    }
}

// MARK: - Color Extensions for Theme
extension Color {
    // Light Theme Colors (matching Android LightColorScheme)
    static let lightBackground = Color(red: 1.0, green: 0.984, blue: 0.996) // LightWhite #FFFBFE
    static let lightPrimary = Color(red: 0.133, green: 0.133, blue: 0.133) // DarkGray
    static let lightSecondary = Color.white
    static let lightTertiary = Color(red: 0.533, green: 0.855, blue: 0.545) // Green #88DA8B
    static let lightPrimaryContainer = Color.white
    static let lightSecondaryContainer = Color(red: 0.953, green: 0.953, blue: 0.949) // LightGray #F3F3F2
    static let lightOnSecondaryContainer = Color(red: 0.953, green: 0.953, blue: 0.949) // LightGray
    static let lightOnPrimary = Color.black
    static let lightOnBackground = Color(red: 0.133, green: 0.133, blue: 0.133) // DarkGray
    static let lightSurface = Color.black
    static let lightInverseSurface = Color(red: 0.894, green: 0.894, blue: 0.882) // LightRed #F3E4E1
    
    // Dark Theme Colors (matching Android DarkColorScheme)
    static let darkBackground = Color(red: 0.133, green: 0.133, blue: 0.145) // LightBlack #222125
    static let darkPrimary = Color(red: 0.953, green: 0.953, blue: 0.949) // LightGray #F3F3F2
    static let darkSecondary = Color(red: 0.953, green: 0.953, blue: 0.949) // LightGray
    static let darkTertiary = Color(red: 0.4, green: 0.647, blue: 0.412) // Green40 #66A569
    static let darkPrimaryContainer = Color.black
    static let darkSecondaryContainer = Color(red: 0.133, green: 0.133, blue: 0.133) // DarkGray
    static let darkOnSecondaryContainer = Color(red: 0.953, green: 0.953, blue: 0.949) // LightGray
    static let darkOnPrimary = Color.white
    static let darkOnBackground = Color.white
    static let darkSurface = Color(red: 0.133, green: 0.133, blue: 0.133) // DarkGray
    static let darkInverseSurface = Color(red: 0.894, green: 0.894, blue: 0.882) // DarkRed #E4422B28
    
    // Red color (consistent across themes)
    static let appRed = Color(red: 0.937, green: 0.325, blue: 0.314) // Red #EF5350
}

// MARK: - Theme-aware Color Helper
struct ThemeColors {
    let background: Color
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let primaryContainer: Color
    let secondaryContainer: Color
    let onSecondaryContainer: Color
    let onPrimary: Color
    let onBackground: Color
    let surface: Color
    let inverseSurface: Color
    let red: Color
    
    static func light() -> ThemeColors {
        return ThemeColors(
            background: .lightBackground,
            primary: .lightPrimary,
            secondary: .lightSecondary,
            tertiary: .lightTertiary,
            primaryContainer: .lightPrimaryContainer,
            secondaryContainer: .lightSecondaryContainer,
            onSecondaryContainer: .lightOnSecondaryContainer,
            onPrimary: .lightOnPrimary,
            onBackground: .lightOnBackground,
            surface: .lightSurface,
            inverseSurface: .lightInverseSurface,
            red: .appRed
        )
    }
    
    static func dark() -> ThemeColors {
        return ThemeColors(
            background: .darkBackground,
            primary: .darkPrimary,
            secondary: .darkSecondary,
            tertiary: .darkTertiary,
            primaryContainer: .darkPrimaryContainer,
            secondaryContainer: .darkSecondaryContainer,
            onSecondaryContainer: .darkOnSecondaryContainer,
            onPrimary: .darkOnPrimary,
            onBackground: .darkOnBackground,
            surface: .darkSurface,
            inverseSurface: .darkInverseSurface,
            red: .appRed
        )
    }
}


