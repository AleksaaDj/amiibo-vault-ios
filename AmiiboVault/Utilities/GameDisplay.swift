import Foundation

struct GenreOption: Identifiable, Hashable {
    var id: String { igdbName }
    let igdbName: String
    let label: String
}

enum GameDisplay {
    static let genreOptions: [GenreOption] = [
        GenreOption(igdbName: "Adventure", label: "Adventure"),
        GenreOption(igdbName: "Arcade", label: "Arcade"),
        GenreOption(igdbName: "Card & Board Game", label: "Board Game"),
        GenreOption(igdbName: "Fighting", label: "Fighting"),
        GenreOption(igdbName: "Hack and slash/Beat 'em up", label: "Beat 'em up"),
        GenreOption(igdbName: "Music", label: "Music"),
        GenreOption(igdbName: "Platform", label: "Platform"),
        GenreOption(igdbName: "Puzzle", label: "Puzzle"),
        GenreOption(igdbName: "Racing", label: "Racing"),
        GenreOption(igdbName: "Role-playing (RPG)", label: "RPG"),
        GenreOption(igdbName: "Shooter", label: "Shooter"),
        GenreOption(igdbName: "Simulator", label: "Simulator"),
        GenreOption(igdbName: "Sport", label: "Sport"),
        GenreOption(igdbName: "Strategy", label: "Strategy"),
        GenreOption(igdbName: "Tactical", label: "Tactical"),
        GenreOption(igdbName: "Turn-based strategy (TBS)", label: "TBS")
    ]

    static let consoles = [
        "Switch",
        "Switch 2",
        "3DS",
        "Wii U"
    ]

    static func genreLabel(_ igdbName: String) -> String {
        genreOptions.first { $0.igdbName.caseInsensitiveCompare(igdbName) == .orderedSame }?.label
            ?? igdbName
    }

    static func gamesByNormalizedName(_ games: [Game]) -> [String: Game] {
        var map: [String: Game] = [:]
        for game in games {
            let key = game.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if !key.isEmpty, map[key] == nil {
                map[key] = game
            }
        }
        return map
    }

    static func matchingGame(named catalogName: String, in gamesByName: [String: Game]) -> Game? {
        let key = catalogName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return gamesByName[key]
    }

    static func formatReleaseDate(_ raw: String?) -> String? {
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty, value.lowercased() != "null" else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        guard let date = parser.date(from: String(value.prefix(10))) else { return value }
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        display.locale = Locale(identifier: "en_US")
        return display.string(from: date)
    }

    static func matchesGenre(_ game: Game, selected: String) -> Bool {
        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let names = (game.genres ?? []).compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !names.isEmpty else { return false }
        let targets = aliases(for: trimmed)
        return names.contains { name in
            targets.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        }
    }

    static func matchesConsole(_ game: Game, selected: String) -> Bool {
        let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let tokens = (game.platforms ?? []).flatMap { platform -> [String] in
            [platform.name, platform.slug].compactMap { $0?.lowercased() }
        }
        guard !tokens.isEmpty else { return false }
        switch trimmed {
        case "Switch 2":
            return tokens.contains { $0.contains("switch 2") || $0.contains("switch-2") || $0.contains("switch2") }
        case "Switch":
            return tokens.contains {
                $0.contains("switch") &&
                !$0.contains("switch 2") &&
                !$0.contains("switch-2") &&
                !$0.contains("switch2")
            }
        case "3DS":
            return tokens.contains { $0.contains("3ds") }
        case "Wii U":
            return tokens.contains { $0.contains("wii u") || $0.contains("wii-u") || $0 == "wiiu" }
        default:
            return tokens.contains { $0.contains(trimmed.lowercased()) }
        }
    }

    private static func aliases(for selected: String) -> Set<String> {
        var values: Set<String> = [selected]
        switch selected.lowercased() {
        case "platform":
            values.insert("Platformer")
        case "role-playing (rpg)":
            values.insert("RPG")
        case "simulator":
            values.insert("Simulation")
        case "sport":
            values.insert("Sports")
        case "card & board game":
            values.formUnion(["Board Games", "Card", "Card Game"])
        default:
            break
        }
        return values
    }
}
