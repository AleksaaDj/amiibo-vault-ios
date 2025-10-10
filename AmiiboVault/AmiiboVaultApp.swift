//
//  AmiiboVaultApp.swift
//  AmiiboVault
//
//  Created by Aleksa Djordjevic on 8. 10. 2025..
//

import SwiftUI
import CoreData
import Firebase

@main
struct AmiiboVaultApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
