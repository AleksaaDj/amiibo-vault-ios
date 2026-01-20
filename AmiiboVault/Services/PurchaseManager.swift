//
//  PurchaseManager.swift
//  AmiiboVault
//
//  In-App Purchase Management using StoreKit 2.0
//  Also implements StoreKit 1.0 observer for App Store promotion support
//

import Foundation
import StoreKit
import Combine

class PurchaseManager: NSObject, ObservableObject, SKPaymentTransactionObserver {
    static let shared = PurchaseManager()
    
    @Published var isNoAdsPurchased: Bool = false
    @Published var isAmiiboScanPurchased: Bool = false
    @Published var isPremiumPurchased: Bool = false
    
    private var updateListenerTask: Task<Void, Never>?
    private let noAdsProductID = "remove_advertising"
    private let scanProductID = "amiibo_scanner"
    private let premiumProductID = "premium_version"
    
    // Track transactions being handled by StoreKit 2.0 to avoid double-handling in StoreKit 1.0 observer
    private var storeKit2HandledTransactions: Set<String> = []
    
    private override init() {
        super.init()
        
        // Register as transaction observer for App Store promotion support
        SKPaymentQueue.default().add(self)
        
        // Load purchase state from UserDefaults
        Task { @MainActor in
            loadPurchaseState()
        }
        
        // Listen for transaction updates (StoreKit 2.0)
        updateListenerTask = listenForTransactions()
        
        // Fetch product details and verify purchases
        Task {
            await requestProducts()
            await verifyPurchases()
        }
    }
    
    @MainActor
    private func loadPurchaseState() {
        // Check UserDefaults for stored purchase status
        isNoAdsPurchased = UserDefaults.standard.bool(forKey: "no_ads_purchased")
        isAmiiboScanPurchased = UserDefaults.standard.bool(forKey: "amiibo_scan_purchased")
        isPremiumPurchased = UserDefaults.standard.bool(forKey: "premium_purchased")
        
        // If premium is purchased, ensure both features are enabled
        if isPremiumPurchased {
            isNoAdsPurchased = true
            isAmiiboScanPurchased = true
        }
    }
    
    @MainActor
    private func savePurchaseState(productID: String) {
        switch productID {
        case noAdsProductID:
            UserDefaults.standard.set(true, forKey: "no_ads_purchased")
            isNoAdsPurchased = true
        case scanProductID:
            UserDefaults.standard.set(true, forKey: "amiibo_scan_purchased")
            isAmiiboScanPurchased = true
        case premiumProductID:
            // Premium purchase enables both features
            UserDefaults.standard.set(true, forKey: "premium_purchased")
            UserDefaults.standard.set(true, forKey: "no_ads_purchased")
            UserDefaults.standard.set(true, forKey: "amiibo_scan_purchased")
            isPremiumPurchased = true
            isNoAdsPurchased = true
            isAmiiboScanPurchased = true
        default:
            break
        }
    }
    
    func requestProducts() async {
        do {
            let _ = try await Product.products(for: [noAdsProductID, scanProductID, premiumProductID])
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
                await MainActor.run {
                    if productID == noAdsProductID {
                        savePurchaseState(productID: noAdsProductID)
                    } else if productID == scanProductID {
                        savePurchaseState(productID: scanProductID)
                    } else if productID == premiumProductID {
                        savePurchaseState(productID: premiumProductID)
                    }
                }
            }
        }
        
        // Ensure premium status is correctly applied after verification
        // This handles cases where premium was purchased but UserDefaults might be out of sync
        await MainActor.run {
            if isPremiumPurchased {
                isNoAdsPurchased = true
                isAmiiboScanPurchased = true
            }
        }
    }
    
    func makeNoAdsPurchase() async {
        await makePurchase(productID: noAdsProductID)
    }
    
    func makeAmiiboScanPurchase() async {
        await makePurchase(productID: scanProductID)
    }
    
    func makePremiumPurchase() async {
        await makePurchase(productID: premiumProductID)
    }
    
    func restorePurchases() async {
        // StoreKit 2.0 automatically restores purchases through Transaction.currentEntitlements
        // We just need to verify them again
        await verifyPurchases()
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
                    // Mark this transaction as handled by StoreKit 2.0
                    await MainActor.run {
                        storeKit2HandledTransactions.insert(String(transaction.id))
                    }
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
    
    @MainActor
    private func handlePurchase(productID: String) async {
        savePurchaseState(productID: productID)
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    // Mark this transaction as handled by StoreKit 2.0
                    await MainActor.run {
                        storeKit2HandledTransactions.insert(String(transaction.id))
                    }
                    await handlePurchase(productID: transaction.productID)
                    await transaction.finish()
                }
            }
        }
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
        updateListenerTask?.cancel()
    }
    
    // MARK: - SKPaymentTransactionObserver (StoreKit 1.0 - Required for App Store promotion)
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // Only handle if not already handled by StoreKit 2.0
                // StoreKit 2.0 purchases will be handled there, this observer is mainly for App Store promotion
                Task { @MainActor in
                    // Check if this transaction was already handled by StoreKit 2.0
                    // If the transaction identifier matches a StoreKit 2.0 transaction, skip it
                    // Note: StoreKit 1.0 and 2.0 use different transaction identifiers, so we check by product ID
                    // If the purchase state is already set, this was likely handled by StoreKit 2.0
                    let productID = transaction.payment.productIdentifier
                    let alreadyPurchased = (productID == noAdsProductID && isNoAdsPurchased) ||
                                         (productID == scanProductID && isAmiiboScanPurchased) ||
                                         (productID == premiumProductID && isPremiumPurchased)
                    
                    if !alreadyPurchased {
                        handleStoreKit1Purchase(productID: productID)
                    }
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                // Handle failed purchase
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                // Handle restored purchase
                Task { @MainActor in
                    let productID = transaction.payment.productIdentifier
                    let alreadyPurchased = (productID == noAdsProductID && isNoAdsPurchased) ||
                                         (productID == scanProductID && isAmiiboScanPurchased) ||
                                         (productID == premiumProductID && isPremiumPurchased)
                    
                    if !alreadyPurchased {
                        handleStoreKit1Purchase(productID: productID)
                    }
                }
                SKPaymentQueue.default().finishTransaction(transaction)
            case .deferred, .purchasing:
                // Transaction is in progress
                break
            @unknown default:
                break
            }
        }
    }
    
    // Required for App Store promotion - called when user taps Buy on promoted IAP
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
        // Return true to proceed with the purchase immediately
        // Or return false and handle it yourself (e.g., show paywall)
        return true
    }
    
    @MainActor
    private func handleStoreKit1Purchase(productID: String) {
        // Sync with StoreKit 2.0 purchase state
        savePurchaseState(productID: productID)
    }
}

