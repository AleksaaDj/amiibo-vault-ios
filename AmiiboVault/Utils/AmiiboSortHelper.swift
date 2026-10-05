import Foundation

enum AmiiboSortHelper {
    static func sort(_ amiibos: [Amiibo], by sortType: String?) -> [Amiibo] {
        guard let sortType else { return amiibos }

        switch sortType {
        case "Name A-Z":
            return amiibos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case "Name Z-A":
            return amiibos.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case "Series A-Z":
            return amiibos.sorted { $0.gameSeries.localizedCaseInsensitiveCompare($1.gameSeries) == .orderedAscending }
        case "Series Z-A":
            return amiibos.sorted { $0.gameSeries.localizedCaseInsensitiveCompare($1.gameSeries) == .orderedDescending }
        case "Character A-Z":
            return amiibos.sorted { $0.character.localizedCaseInsensitiveCompare($1.character) == .orderedAscending }
        case "Character Z-A":
            return amiibos.sorted { $0.character.localizedCaseInsensitiveCompare($1.character) == .orderedDescending }
        case "Release (Asc)", "Release Date A-Z", "Release Date (Oldest)":
            return sortByRelease(amiibos: amiibos, ascending: true)
        case "Release (Dsc)", "Release Date Z-A", "Release Date (Newest)":
            return sortByRelease(amiibos: amiibos, ascending: false)
        default:
            return amiibos
        }
    }

    static func sortByRelease(amiibos: [Amiibo], ascending: Bool) -> [Amiibo] {
        amiibos.sorted { lhs, rhs in
            let lhsMissing = isMissingRelease(lhs)
            let rhsMissing = isMissingRelease(rhs)
            if lhsMissing != rhsMissing {
                return !lhsMissing
            }
            let lhsJp = lhs.release?.jp ?? ""
            let rhsJp = rhs.release?.jp ?? ""
            return ascending ? (lhsJp < rhsJp) : (lhsJp > rhsJp)
        }
    }

    private static func isMissingRelease(_ amiibo: Amiibo) -> Bool {
        guard let jp = amiibo.release?.jp else { return true }
        return jp.isEmpty || jp == "null"
    }
}
