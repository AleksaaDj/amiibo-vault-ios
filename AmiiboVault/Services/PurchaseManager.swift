//
//  PurchaseManager.swift
//  AmiiboVault
//
//  In-App Purchase Management using StoreKit 2.0
//

import Foundation
import StoreKit
import Combine

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var isNoAdsPurchased: Bool = false
    @Published var isAmiiboScanPurchased: Bool = false
    
    private var updateListenerTask: Task<Void, Never>?
    private let noAdsProductID = "no_ads"
    private let scanProductID = "amiibo_scan"
    
    private init() {
        // Load purchase state from UserDefaults
        loadPurchaseState()
        
        // Listen for transaction updates
        updateListenerTask = listenForTransactions()
        
        // Fetch product details and verify purchases
        Task {
            await requestProducts()
            await verifyPurchases()
        }
    }
    
    private func loadPurchaseState() {
        // Check UserDefaults for stored purchase status
        isNoAdsPurchased = UserDefaults.standard.bool(forKey: "no_ads_purchased")
        isAmiiboScanPurchased = UserDefaults.standard.bool(forKey: "amiibo_scan_purchased")
    }
    
    private func savePurchaseState(productID: String) {
        switch productID {
        case noAdsProductID:
            UserDefaults.standard.set(true, forKey: "no_ads_purchased")
            isNoAdsPurchased = true
        case scanProductID:
            UserDefaults.standard.set(true, forKey: "amiibo_scan_purchased")
            isAmiiboScanPurchased = true
        default:
            break
        }
    }
    
    func requestProducts() async {
        do {
            let _ = try await Product.products(for: [noAdsProductID, scanProductID])
        } catch {
            // Handle error silently
        }
    }
    
    private func verifyPurchases() async {
        // Check current entitlements to see if user already owns the products
        // Note: currentEntitlements are already finished transactions - don't finish again
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                let productID = transaction.productID
                if productID == noAdsProductID {
                    savePurchaseState(productID: noAdsProductID)
                } else if productID == scanProductID {
                    savePurchaseState(productID: scanProductID)
                }
            }
        }
    }
    
    func makeNoAdsPurchase() async {
        await makePurchase(productID: noAdsProductID)
    }
    
    func makeAmiiboScanPurchase() async {
        await makePurchase(productID: scanProductID)
    }
    
    private func makePurchase(productID: String) async {
        do {
            guard let product = try await Product.products(for: [productID]).first else {
                return
            }
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await handlePurchase(productID: productID)
                    await transaction.finish()
                case .unverified:
                    break
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // Handle error silently
        }
    }
    
    private func handlePurchase(productID: String) async {
        savePurchaseState(productID: productID)
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await handlePurchase(productID: transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
}

