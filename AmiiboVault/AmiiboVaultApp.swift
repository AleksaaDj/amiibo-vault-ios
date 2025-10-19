//
//  AmiiboVaultApp.swift
//  AmiiboVault
//
//  Created by Aleksa Djordjevic on 8. 10. 2025..
//

import SwiftUI
import CoreData
import Firebase
import FirebaseAnalytics

@main
struct AmiiboVaultApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        FirebaseApp.configure()
        
        // Enable Analytics collection (should be enabled by default)
        Analytics.setAnalyticsCollectionEnabled(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
