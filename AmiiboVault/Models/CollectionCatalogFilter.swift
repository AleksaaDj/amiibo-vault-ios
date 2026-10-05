import Foundation

enum CollectionCatalogFilter: String, CaseIterable {
    case all
    case notCollected
    case inCollectionOnly

    var label: String {
        switch self {
        case .all: return "All"
        case .notCollected: return "Missing"
        case .inCollectionOnly: return "Collected"
        }
    }
}
