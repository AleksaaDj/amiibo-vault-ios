import Foundation

// MARK: - Amiibo
struct Amiibo: Codable, Identifiable, Hashable {
    let id = UUID()
    let amiiboSeries: String
    let character: String
    let gameSeries: String
    let head: String
    let image: String
    let name: String
    let release: Release?
    let tail: String
    let type: String
    let featured: Bool
    let color: Int
    var isInCollection: Bool
    var isInWishlist: Bool
    
    enum CodingKeys: String, CodingKey {
        case amiiboSeries, character, gameSeries, head, image, name, release, tail, type
    }
    
    init(amiiboSeries: String = "", character: String = "", gameSeries: String = "", head: String = "", image: String = "", name: String = "", release: Release? = nil, tail: String = "", type: String = "", featured: Bool = false, color: Int = 0, isInCollection: Bool = false, isInWishlist: Bool = false) {
        self.amiiboSeries = amiiboSeries
        self.character = character
        self.gameSeries = gameSeries
        self.head = head
        self.image = image
        self.name = name
        self.release = release
        self.tail = tail
        self.type = type
        self.featured = featured
        self.color = color
        self.isInCollection = isInCollection
        self.isInWishlist = isInWishlist
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amiiboSeries = try container.decode(String.self, forKey: .amiiboSeries)
        character = try container.decode(String.self, forKey: .character)
        gameSeries = try container.decode(String.self, forKey: .gameSeries)
        head = try container.decode(String.self, forKey: .head)
        image = try container.decode(String.self, forKey: .image)
        name = try container.decode(String.self, forKey: .name)
        release = try container.decodeIfPresent(Release.self, forKey: .release)
        tail = try container.decode(String.self, forKey: .tail)
        type = try container.decode(String.self, forKey: .type)
        featured = false
        color = 0
        isInCollection = false
        isInWishlist = false
    }
}

// MARK: - Release
struct Release: Codable, Hashable {
    let au: String?
    let eu: String?
    let jp: String?
    let na: String?
    
    init(au: String? = "", eu: String? = "", jp: String? = "", na: String? = "") {
        self.au = au
        self.eu = eu
        self.jp = jp
        self.na = na
    }
}

// MARK: - AmiiboCollection
struct AmiiboCollection: Codable, Identifiable, Hashable {
    let id = UUID()
    let amiiboSeries: String
    let character: String
    let gameSeries: String
    let head: String
    let image: String
    let name: String
    let release: Release?
    let tail: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case amiiboSeries, character, gameSeries, head, image, name, release, tail, type
    }
}

// MARK: - AmiiboWishlist
struct AmiiboWishlist: Codable, Identifiable, Hashable {
    let id = UUID()
    let amiiboSeries: String
    let character: String
    let gameSeries: String
    let head: String
    let image: String
    let name: String
    let release: Release
    let tail: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case amiiboSeries, character, gameSeries, head, image, name, release, tail, type
    }
}

// MARK: - API Response Models
struct AmiiboListResponse: Codable {
    let amiibo: [Amiibo]
}

// MARK: - Game Models
struct Game: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let backgroundImage: String?
    let genres: [Genre]?
    let metacritic: Int?
    let platforms: [Platform]?
    let rating: Double?
    let ratingsCount: Int?
    let released: String?
    let slug: String?
    let shortScreenshots: [Screenshot]?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case backgroundImage = "background_image"
        case genres, metacritic, platforms, rating
        case ratingsCount = "ratings_count"
        case released, slug
        case shortScreenshots = "short_screenshots"
    }
    
    init(id: Int, name: String?, backgroundImage: String?, genres: [Genre]?, metacritic: Int?, platforms: [Platform]?, rating: Double?, ratingsCount: Int?, released: String?, slug: String?, shortScreenshots: [Screenshot]?) {
        self.id = id
        self.name = name
        self.backgroundImage = backgroundImage
        self.genres = genres
        self.metacritic = metacritic
        self.platforms = platforms
        self.rating = rating
        self.ratingsCount = ratingsCount
        self.released = released
        self.slug = slug
        self.shortScreenshots = shortScreenshots
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        genres = try container.decodeIfPresent([Genre].self, forKey: .genres)
        metacritic = try container.decodeIfPresent(Int.self, forKey: .metacritic)
        platforms = try container.decodeIfPresent([Platform].self, forKey: .platforms)
        rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        ratingsCount = try container.decodeIfPresent(Int.self, forKey: .ratingsCount)
        released = try container.decodeIfPresent(String.self, forKey: .released)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        shortScreenshots = try container.decodeIfPresent([Screenshot].self, forKey: .shortScreenshots)
    }
}

struct Genre: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String?
    let slug: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug
    }
}

struct Platform: Codable, Identifiable, Hashable {
    let id: Int?
    let name: String?
    let slug: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug
    }
}

struct Screenshot: Codable, Identifiable, Hashable {
    let id: Int?
    let image: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id)
        image = try container.decodeIfPresent(String.self, forKey: .image)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, image
    }
}

// MARK: - Games API Response
struct GamesListResponse: Codable {
    let results: [Game]
    let count: Int
    let next: String?
    let previous: String?
}

// MARK: - Amiibo Games (for compatibility)
struct AmiiboGames: Codable, Identifiable, Hashable {
    let id = UUID()
    let amiiboSeries: String
    let character: String
    let gameSeries: String
    let games3DS: [Games3DS]
    let gamesSwitch: [GamesSwitch]
    let gamesWiiU: [GamesWiiU]
    let head: String
    let image: String
    let name: String
    let release: Release
    let tail: String
    let type: String
    
    enum CodingKeys: String, CodingKey {
        case amiiboSeries, character, gameSeries, games3DS, gamesSwitch, gamesWiiU, head, image, name, release, tail, type
    }
}

struct Games3DS: Codable, Hashable {
    let amiiboUsage: [AmiiboUsage]
    let gameID: [String]
    let gameName: String
    
    enum CodingKeys: String, CodingKey {
        case amiiboUsage
        case gameID = "gameID"
        case gameName
    }
}

struct GamesSwitch: Codable, Hashable {
    let amiiboUsage: [AmiiboUsage]
    let gameID: [String]
    let gameName: String
    
    enum CodingKeys: String, CodingKey {
        case amiiboUsage
        case gameID = "gameID"
        case gameName
    }
}

struct GamesWiiU: Codable, Hashable {
    let amiiboUsage: [AmiiboUsage]
    let gameID: [String]
    let gameName: String
    
    enum CodingKeys: String, CodingKey {
        case amiiboUsage
        case gameID = "gameID"
        case gameName
    }
}

struct AmiiboUsage: Codable, Hashable {
    let usage: String
    let write: Bool
}

struct Games: Codable {
    let amiibo: [AmiiboGames]
}
