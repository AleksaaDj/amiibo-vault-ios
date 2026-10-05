import Foundation

struct UpcomingAmiibo: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let series: String
    let releaseDate: String
    let type: String
    let image: String
    let description: String
    let sourceUrl: String
}

struct UpcomingAmiiboListResponse: Codable {
    let items: [UpcomingAmiibo]
}
