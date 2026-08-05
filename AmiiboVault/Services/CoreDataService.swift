import Foundation
import CoreData
import Combine

// MARK: - Core Data Service
class CoreDataService: ObservableObject {
    static let shared = CoreDataService()
    
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    private init() {
        container = NSPersistentContainer(name: "AmiiboVault")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        context = container.viewContext
    }
    
    // MARK: - Save Context
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    // MARK: - Game Operations
    func getAllGames(sortType: String? = nil) -> [Game] {
        let request: NSFetchRequest<GameEntity> = GameEntity.fetchRequest()
        request.sortDescriptors = getGameSortDescriptors(for: sortType)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                convertGameEntityToGame(entity)
            }
        } catch {
            print("Failed to fetch games: \(error)")
            return []
        }
    }
    
    func searchGames(query: String, sortType: String? = nil) -> [Game] {
        let request: NSFetchRequest<GameEntity> = GameEntity.fetchRequest()
        
        if !query.isEmpty {
            request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        }
        
        request.sortDescriptors = getGameSortDescriptors(for: sortType)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                convertGameEntityToGame(entity)
            }
        } catch {
            print("Failed to search games: \(error)")
            return []
        }
    }
    
    func searchGamesByGenre(genre: String, sortType: String? = nil) -> [Game] {
        let request: NSFetchRequest<GameEntity> = GameEntity.fetchRequest()
        request.predicate = NSPredicate(format: "genres CONTAINS[cd] %@", genre)
        request.sortDescriptors = getGameSortDescriptors(for: sortType)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                convertGameEntityToGame(entity)
            }
        } catch {
            print("Failed to search games by genre: \(error)")
            return []
        }
    }
    
    func searchGamesFiltered(query: String, genre: String, sortType: String? = nil) -> [Game] {
        let request: NSFetchRequest<GameEntity> = GameEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if !query.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", query))
        }
        
        if !genre.isEmpty {
            predicates.append(NSPredicate(format: "genres CONTAINS[cd] %@", genre))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = getGameSortDescriptors(for: sortType)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                convertGameEntityToGame(entity)
            }
        } catch {
            print("Failed to search games filtered: \(error)")
            return []
        }
    }
    
    func saveGames(_ games: [Game]) {
        for game in games {
            let request: NSFetchRequest<GameEntity> = GameEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %d", game.id)
            
            do {
                let existingEntities = try context.fetch(request)
                let entity = existingEntities.first ?? GameEntity(context: context)
                
                entity.id = Int32(game.id)
                entity.name = game.name
                entity.backgroundImage = game.backgroundImage
                entity.slug = game.slug
                entity.released = game.released
                entity.rating = game.rating ?? 0.0
                entity.ratingsCount = Int32(game.ratingsCount ?? 0)
                entity.metacritic = Int32(game.metacritic ?? 0)
                
                // Convert arrays to JSON strings (similar to Android approach)
                if let genres = game.genres {
                    let genresData = try JSONEncoder().encode(genres)
                    entity.genres = String(data: genresData, encoding: .utf8)
                }
                
                if let platforms = game.platforms {
                    let platformsData = try JSONEncoder().encode(platforms)
                    entity.platforms = String(data: platformsData, encoding: .utf8)
                }
                
                if let screenshots = game.shortScreenshots {
                    let screenshotsData = try JSONEncoder().encode(screenshots)
                    entity.shortScreenshots = String(data: screenshotsData, encoding: .utf8)
                }
                
            } catch {
                print("Failed to save game: \(error)")
            }
        }
        
        save()
    }
    
    private func convertGameEntityToGame(_ entity: GameEntity) -> Game {
        // Parse genres from JSON string
        var genres: [Genre]? = nil
        if let genresString = entity.genres, !genresString.isEmpty {
            if let data = genresString.data(using: .utf8) {
                genres = try? JSONDecoder().decode([Genre].self, from: data)
            }
        }
        
        // Parse platforms from JSON string
        var platforms: [Platform]? = nil
        if let platformsString = entity.platforms, !platformsString.isEmpty {
            if let data = platformsString.data(using: .utf8) {
                platforms = try? JSONDecoder().decode([Platform].self, from: data)
            }
        }
        
        // Parse screenshots from JSON string
        var screenshots: [Screenshot]? = nil
        if let screenshotsString = entity.shortScreenshots, !screenshotsString.isEmpty {
            if let data = screenshotsString.data(using: .utf8) {
                screenshots = try? JSONDecoder().decode([Screenshot].self, from: data)
            }
        }
        
        return Game(
            id: Int(entity.id),
            name: entity.name,
            backgroundImage: entity.backgroundImage,
            genres: genres,
            metacritic: entity.metacritic > 0 ? Int(entity.metacritic) : nil,
            platforms: platforms,
            rating: entity.rating > 0 ? entity.rating : nil,
            ratingsCount: entity.ratingsCount > 0 ? Int(entity.ratingsCount) : nil,
            released: entity.released,
            slug: entity.slug,
            shortScreenshots: screenshots
        )
    }
    
    private func getGameSortDescriptors(for sortType: String?) -> [NSSortDescriptor] {
        switch sortType {
        case "Name (A-Z)":
            return [NSSortDescriptor(keyPath: \GameEntity.name, ascending: true)]
        case "Name (Z-A)":
            return [NSSortDescriptor(keyPath: \GameEntity.name, ascending: false)]
        case "Rating (High to Low)":
            return [NSSortDescriptor(keyPath: \GameEntity.rating, ascending: false)]
        case "Rating (Low to High)":
            return [NSSortDescriptor(keyPath: \GameEntity.rating, ascending: true)]
        case "Release Date (Newest)":
            return [NSSortDescriptor(keyPath: \GameEntity.released, ascending: false)]
        case "Release Date (Oldest)":
            return [NSSortDescriptor(keyPath: \GameEntity.released, ascending: true)]
        default:
            return [NSSortDescriptor(keyPath: \GameEntity.name, ascending: true)]
        }
    }
    
    // MARK: - Amiibo Operations
    func getAllAmiibos(sortType: String? = nil) -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.sortDescriptors = getSortDescriptors(for: sortType)
        
        
        do {
            let entities = try context.fetch(request)
            let amiibos = entities.map { entity in
                // Convert release data from string (Android approach)
                let release: Release?
                if let releaseDataString = entity.value(forKey: "releaseData") as? String, !releaseDataString.isEmpty {
                    let components = releaseDataString.split(separator: ",")
                    if components.count == 4 {
                        release = Release(
                            au: String(components[0]),
                            eu: String(components[1]),
                            jp: String(components[2]),
                            na: String(components[3])
                        )
                    } else {
                        release = nil
                    }
                } else {
                    release = nil
                }
                
                return Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: release,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
            return amiibos
        } catch {
            print("Failed to fetch amiibos: \(error)")
            return []
        }
    }
    
    func searchAmiibos(query: String, sortType: String? = nil) -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name CONTAINS[cd] %@", query)
        request.sortDescriptors = getSortDescriptors(for: sortType)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: nil,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
        } catch {
            print("Failed to search amiibos: \(error)")
            return []
        }
    }
    
    func getFilteredAmiibos(searchQuery: String?, typeFilter: String?, setFilter: String?, sortType: String? = nil) -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        
        // Build compound predicate for all filters
        var predicates: [NSPredicate] = []
        
        // Search query filter
        if let searchQuery = searchQuery, !searchQuery.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", searchQuery))
        }
        
        // Type filter
        if let typeFilter = typeFilter, !typeFilter.isEmpty {
            predicates.append(NSPredicate(format: "type CONTAINS[cd] %@", typeFilter))
        }
        
        // Set filter
        if let setFilter = setFilter, !setFilter.isEmpty {
            predicates.append(NSPredicate(format: "amiiboSeries CONTAINS[cd] %@", setFilter))
        }
        
        // Combine all predicates with AND
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = getSortDescriptors(for: sortType)
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                // Parse release data from string
                let releaseData = entity.value(forKey: "releaseData") as? String
                let release = parseReleaseFromString(releaseData)
                
                return Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: release,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
        } catch {
            print("Failed to get filtered amiibos: \(error)")
            return []
        }
    }
    
    func getAmiiboByTail(_ tail: String) -> Amiibo? {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tail == %@", tail)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            guard let entity = entities.first else { return nil }
            
            // Convert release data from string (Android approach)
            let release: Release?
            if let releaseDataString = entity.value(forKey: "releaseData") as? String, !releaseDataString.isEmpty {
                let components = releaseDataString.split(separator: ",")
                if components.count == 4 {
                    release = Release(
                        au: String(components[0]),
                        eu: String(components[1]),
                        jp: String(components[2]),
                        na: String(components[3])
                    )
                } else {
                    release = nil
                }
            } else {
                release = nil
            }
            
            return Amiibo(
                amiiboSeries: entity.amiiboSeries ?? "",
                character: entity.character ?? "",
                gameSeries: entity.gameSeries ?? "",
                head: entity.head ?? "",
                image: entity.image ?? "",
                name: entity.name ?? "",
                release: release,
                tail: entity.tail ?? "",
                type: entity.type ?? "",
                featured: entity.featured,
                color: Int(entity.color),
                isInCollection: entity.isInCollectionValue,
                isInWishlist: entity.isInWishlistValue
            )
        } catch {
            print("Failed to fetch amiibo by tail: \(error)")
            return nil
        }
    }
    
    /// `viewContext` must run on the main queue; catalog completion may arrive on a background queue.
    /// Copy the array and run all work inside `performAndWait` so Core Data internal collections are never touched off-queue.
    func upsertAmiibos(_ amiibos: [Amiibo]) {
        let items = Array(amiibos)
        context.performAndWait {
            for amiibo in items {
                let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
                request.predicate = NSPredicate(format: "tail == %@", amiibo.tail)
                request.fetchLimit = 1
                
                do {
                    let existingEntities = try context.fetch(request)
                    if let existingEntity = existingEntities.first {
                        // Update existing
                        existingEntity.amiiboSeries = amiibo.amiiboSeries
                        existingEntity.character = amiibo.character
                        existingEntity.gameSeries = amiibo.gameSeries
                        existingEntity.head = amiibo.head
                        existingEntity.image = amiibo.image
                        existingEntity.name = amiibo.name
                        existingEntity.tail = amiibo.tail
                        existingEntity.type = amiibo.type
                        existingEntity.featured = amiibo.featured
                        existingEntity.color = Int32(amiibo.color)
                        
                        // Save release data as string (Android approach)
                        existingEntity.setValue(convertReleaseToString(amiibo.release), forKey: "releaseData")
                        
                        // Keep existing collection/wishlist status
                    } else {
                        // Create new
                        let newEntity = AmiiboEntity(context: context)
                        newEntity.amiiboSeries = amiibo.amiiboSeries
                        newEntity.character = amiibo.character
                        newEntity.gameSeries = amiibo.gameSeries
                        newEntity.head = amiibo.head
                        newEntity.image = amiibo.image
                        newEntity.name = amiibo.name
                        newEntity.tail = amiibo.tail
                        newEntity.type = amiibo.type
                        newEntity.featured = amiibo.featured
                        newEntity.color = Int32(amiibo.color)
                        newEntity.isInCollectionValue = false
                        newEntity.isInWishlistValue = false
                        
                        // Save release data as string (Android approach)
                        newEntity.setValue(convertReleaseToString(amiibo.release), forKey: "releaseData")
                    }
                } catch {
                    print("Failed to upsert amiibo: \(error)")
                }
            }
            save()
        }
    }
    
    // Convert Release to string (Android approach: "au,eu,jp,na")
    private func convertReleaseToString(_ release: Release?) -> String? {
        guard let release = release else { 
            return nil 
        }
        
        // Check if any release data exists
        let hasAnyData = !(release.au?.isEmpty ?? true) || 
                        !(release.eu?.isEmpty ?? true) || 
                        !(release.jp?.isEmpty ?? true) || 
                        !(release.na?.isEmpty ?? true)
        
        if hasAnyData {
            let result = "\(release.au ?? ""),\(release.eu ?? ""),\(release.jp ?? ""),\(release.na ?? "")"
            return result
        } else {
            return nil
        }
    }
    
    
    func updateAmiiboCollectionStatus(tail: String, isInCollection: Bool) {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tail == %@", tail)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.isInCollectionValue = isInCollection
                save()
            }
        } catch {
            print("Failed to update collection status: \(error)")
        }
    }
    
    func updateAmiiboWishlistStatus(tail: String, isInWishlist: Bool) {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tail == %@", tail)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.isInWishlistValue = isInWishlist
                save()
            }
        } catch {
            print("Failed to update wishlist status: \(error)")
        }
    }
    
    func getCollectionAmiibos() -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isInCollectionValue == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: nil,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
        } catch {
            print("Failed to fetch collection amiibos: \(error)")
            return []
        }
    }
    
    func getWishlistAmiibos() -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isInWishlistValue == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: nil,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
        } catch {
            print("Failed to fetch wishlist amiibos: \(error)")
            return []
        }
    }
    
    func getNotCollectedAmiibos() -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isInCollectionValue == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.map { entity in
                Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: nil,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
        } catch {
            print("Failed to fetch not collected amiibos: \(error)")
            return []
        }
    }
    
    func clearAllAmiibos() {
        let request: NSFetchRequest<NSFetchRequestResult> = AmiiboEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
        
        do {
            try context.execute(deleteRequest)
            save()
        } catch {
            print("Failed to clear amiibos: \(error)")
        }
    }
    
    func hasLocalData() -> Bool {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            print("Failed to check local data: \(error)")
            return false
        }
    }
    
    private func getSortDescriptors(for sortType: String?) -> [NSSortDescriptor] {
        guard let sortType = sortType else {
            return [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        }
        
        switch sortType {
        case "Name A-Z":
            return [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        case "Name Z-A":
            return [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: false)]
        case "Series A-Z":
            return [NSSortDescriptor(keyPath: \AmiiboEntity.amiiboSeries, ascending: true)]
        case "Series Z-A":
            return [NSSortDescriptor(keyPath: \AmiiboEntity.amiiboSeries, ascending: false)]
        case "Character A-Z":
            return [NSSortDescriptor(keyPath: \AmiiboEntity.character, ascending: true)]
        case "Character Z-A":
            return [NSSortDescriptor(keyPath: \AmiiboEntity.character, ascending: false)]
        case "Release Date (Newest)", "Release Date (Oldest)":
            // For release date sorting, we'll sort by name as fallback since Core Data can't sort by parsed date strings
            // The actual release date sorting will be handled in the ViewModel
            return [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        default:
            return [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        }
    }
    
    private func parseReleaseFromString(_ releaseData: String?) -> Release? {
        guard let releaseData = releaseData, !releaseData.isEmpty else { return nil }
        
        let components = releaseData.components(separatedBy: ",")
        guard components.count >= 4 else { return nil }
        
        let au = components[0].isEmpty ? nil : components[0]
        let eu = components[1].isEmpty ? nil : components[1]
        let jp = components[2].isEmpty ? nil : components[2]
        let na = components[3].isEmpty ? nil : components[3]
        
        // Only create Release if at least one date exists
        if au != nil || eu != nil || jp != nil || na != nil {
            return Release(au: au, eu: eu, jp: jp, na: na)
        }
        
        return nil
    }
    
    // MARK: - Featured Amiibo Management
    func getFeaturedAmiibo() -> [Amiibo] {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "featured == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AmiiboEntity.name, ascending: true)]
        
        do {
            let entities = try context.fetch(request)
            return entities.compactMap { entity in
                // Parse release data
                let release: Release?
                if let releaseData = entity.value(forKey: "releaseData") as? String {
                    release = parseReleaseFromString(releaseData)
                } else {
                    release = nil
                }
                
                return Amiibo(
                    amiiboSeries: entity.amiiboSeries ?? "",
                    character: entity.character ?? "",
                    gameSeries: entity.gameSeries ?? "",
                    head: entity.head ?? "",
                    image: entity.image ?? "",
                    name: entity.name ?? "",
                    release: release,
                    tail: entity.tail ?? "",
                    type: entity.type ?? "",
                    featured: entity.featured,
                    color: Int(entity.color),
                    isInCollection: entity.isInCollectionValue,
                    isInWishlist: entity.isInWishlistValue
                )
            }
        } catch {
            print("Failed to fetch featured amiibo: \(error)")
            return []
        }
    }
    
    func setFeaturedAmiibo(amiibo: Amiibo, featured: Bool, color: Int) {
        let request: NSFetchRequest<AmiiboEntity> = AmiiboEntity.fetchRequest()
        request.predicate = NSPredicate(format: "tail == %@", amiibo.tail)
        request.fetchLimit = 1
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                entity.featured = featured
                // Convert color to Int32 safely, handling negative values
                entity.color = Int32(bitPattern: UInt32(color & 0xFFFFFFFF))
                try context.save()
            }
        } catch {
            print("Failed to set featured amiibo: \(error)")
        }
    }
}
