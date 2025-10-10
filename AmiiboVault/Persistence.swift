//
//  Persistence.swift
//  AmiiboVault
//
//  Created by Aleksa Djordjevic on 8. 10. 2025..
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create some sample Amiibo data for previews
        let sampleAmiibos = [
            ("Mario", "Mario", "Super Mario", "00000000", "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_00000000-00000002.png", "Mario", "00000002", "Figure", false, 0),
            ("Luigi", "Luigi", "Super Mario", "00010000", "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_00010000-00000002.png", "Luigi", "00000002", "Figure", false, 0),
            ("Peach", "Peach", "Super Mario", "00020000", "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_00020000-00000002.png", "Peach", "00000002", "Figure", false, 0)
        ]
        
        for (name, character, gameSeries, head, image, amiiboName, tail, type, featured, color) in sampleAmiibos {
            let newAmiibo = AmiiboEntity(context: viewContext)
            newAmiibo.name = amiiboName
            newAmiibo.character = character
            newAmiibo.gameSeries = gameSeries
            newAmiibo.amiiboSeries = name
            newAmiibo.head = head
            newAmiibo.image = image
            newAmiibo.tail = tail
            newAmiibo.type = type
            newAmiibo.featured = featured
            newAmiibo.color = Int32(color)
            newAmiibo.isInCollectionValue = false
            newAmiibo.isInWishlistValue = false
        }
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AmiiboVault")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
