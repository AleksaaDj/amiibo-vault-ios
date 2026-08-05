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
import FirebaseDatabase
import FacebookCore
import AppTrackingTransparency
import os.log

// AppDelegate to handle Facebook SDK initialization and app lifecycle events
class AppDelegate: NSObject, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.softwavegames.amiibovault", category: "FacebookSDK")
    private var hasRequestedTracking = false
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Enable Facebook SDK debug logging (remove in production)
        Settings.shared.enableLoggingBehavior(.appEvents)
        
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        
        // Verify SDK initialization
        if let appID = Settings.shared.appID {
            logger.info("Facebook SDK initialized with App ID: \(appID)")
            print("✅ Facebook SDK initialized - App ID: \(appID)")
        } else {
            logger.error("Facebook SDK initialization failed - App ID not found")
            print("❌ Facebook SDK initialization failed - Check Info.plist")
        }
        
        // Verify SDK version (should be 17.x or higher)
        let sdkVersion = Settings.shared.sdkVersion
        logger.info("Facebook SDK version: \(sdkVersion)")
        print("📦 Facebook SDK version: \(sdkVersion)")
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Activate Facebook App Events when app comes to foreground
        AppEvents.shared.activateApp()
        logger.info("activateApp() called")
        print("📊 Facebook activateApp() called - Event should be sent")
        
        // Request App Tracking Transparency after app becomes active (better UX)
        // Only request once per app session
        if !hasRequestedTracking {
            requestTrackingPermission()
        } else {
            // Update isAdvertiserTrackingEnabled based on current status
            updateAdvertiserTrackingEnabled()
        }
    }
    
    private func requestTrackingPermission() {
        guard !hasRequestedTracking else { return }
        
        if #available(iOS 14, *) {
            // Check current authorization status
            let currentStatus = ATTrackingManager.trackingAuthorizationStatus
            
            // Only request if status is .notDetermined
            guard currentStatus == .notDetermined else {
                // Status already determined, update Facebook SDK
                updateAdvertiserTrackingEnabled()
                hasRequestedTracking = true
                return
            }
            
            // Request App Tracking Transparency permission
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    self?.hasRequestedTracking = true
                    let statusString = String(describing: status)
                    self?.logger.info("ATTrackingManager status: \(statusString)")
                    print("📱 App Tracking Status: \(statusString)")
                    
                    // Set isAdvertiserTrackingEnabled after authorization
                    self?.updateAdvertiserTrackingEnabled()
                }
            }
        } else {
            // iOS 13 and below - tracking is allowed by default
            updateAdvertiserTrackingEnabled()
            hasRequestedTracking = true
        }
    }
    
    private func updateAdvertiserTrackingEnabled() {
        if #available(iOS 14, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            // Set isAdvertiserTrackingEnabled based on authorization status
            // true if authorized, false otherwise
            let isEnabled = (status == .authorized)
            
            // Note: For FBSDK v17+ on iOS 17+, this is deprecated but still works
            // Setting it explicitly ensures compatibility and clear intent
            Settings.shared.isAdvertiserTrackingEnabled = isEnabled
            
            logger.info("isAdvertiserTrackingEnabled set to: \(isEnabled) (ATT status: \(String(describing: status)))")
            print("🔐 isAdvertiserTrackingEnabled set to: \(isEnabled)")
        } else {
            // iOS 13 and below - tracking allowed by default
            Settings.shared.isAdvertiserTrackingEnabled = true
            logger.info("isAdvertiserTrackingEnabled set to: true (iOS < 14)")
            print("🔐 isAdvertiserTrackingEnabled set to: true (iOS < 14)")
        }
    }
}

@main
struct AmiiboVaultApp: App {
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        FirebaseApp.configure()
        Database.database().isPersistenceEnabled = true
        Analytics.setAnalyticsCollectionEnabled(true)
        _ = PurchaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
