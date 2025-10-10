import Foundation
import CoreNFC
import Combine

class NTAG215Reader: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var scannedAmiibo: Amiibo?
    @Published var errorMessage: String?
    
    private var nfcSession: NFCTagReaderSession?
    private var amiiboRepository: AmiiboRepository?
    
    override init() {
        super.init()
    }
    
    func setRepository(_ repository: AmiiboRepository) {
        self.amiiboRepository = repository
    }
    
    func startScanning() {
        print("🔍 NTAG215: Starting scan...")
        
        guard NFCTagReaderSession.readingAvailable else {
            print("❌ NTAG215: NFC not available")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "NFC is not available on this device"
            }
            return
        }
        
        print("✅ NTAG215: NFC available, creating session...")
        
        // Clear any previous session
        nfcSession?.invalidate()
        nfcSession = nil
        
        nfcSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        nfcSession?.alertMessage = "Hold your iPhone near an Amiibo to scan it"
        
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = true
        }
        
        nfcSession?.begin()
        print("✅ NTAG215: Session started")
    }
    
    func stopScanning() {
        print("🛑 NTAG215: Stopping scan...")
        nfcSession?.invalidate()
        nfcSession = nil
        
        DispatchQueue.main.async {
            self.isScanning = false
        }
    }
    
    func clearScannedAmiibo() {
        DispatchQueue.main.async { [weak self] in
            self?.scannedAmiibo = nil
            self?.errorMessage = nil
        }
    }
}

// MARK: - NFCTagReaderSessionDelegate
extension NTAG215Reader: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("✅ NTAG215: Session became active")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("❌ NTAG215: Session invalidated with error: \(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isScanning = false
            
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    print("ℹ️ NTAG215: User cancelled")
                    break
                case .readerSessionInvalidationErrorSessionTimeout:
                    print("⏰ NTAG215: Session timeout")
                    self.errorMessage = "Scanning timed out. Please try again."
                case .readerSessionInvalidationErrorSystemIsBusy:
                    print("🔒 NTAG215: System busy")
                    self.errorMessage = "System is busy. Please try again."
                default:
                    print("❌ NTAG215: Other error: \(nfcError.localizedDescription)")
                    self.errorMessage = "NFC Error: \(nfcError.localizedDescription)"
                }
            } else {
                print("❌ NTAG215: Unknown error: \(error.localizedDescription)")
                self.errorMessage = "NFC Error: \(error.localizedDescription)"
            }
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("✅ NTAG215: Detected \(tags.count) tags")
        
        guard let firstTag = tags.first else {
            print("❌ NTAG215: No tags detected")
            session.invalidate(errorMessage: "No tags found.")
            return
        }
        
        print("🔍 NTAG215: Processing detected tag...")
        session.alertMessage = "Amiibo detected! Reading data..."
        
        // Connect to the tag first
        session.connect(to: firstTag) { [weak self] (error) in
            if let error = error {
                print("❌ NTAG215: Error connecting to tag: \(error.localizedDescription)")
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            print("✅ NTAG215: Connected to tag")
            
            // Check if it's a MiFare tag (NTAG215 is a type of MiFare)
            if case let NFCTag.miFare(miFareTag) = firstTag {
                print("✅ NTAG215: Confirmed MiFare tag")
                self?.readAmiiboData(from: miFareTag, session: session)
            } else {
                print("❌ NTAG215: Not a MiFare tag")
                session.invalidate(errorMessage: "Invalid tag type for Amiibo.")
            }
        }
    }
    
    private func readAmiiboData(from tag: NFCMiFareTag, session: NFCTagReaderSession) {
        print("🔍 NTAG215: Reading Amiibo data...")
        
        // Try to read page 22 first (where tail ID is typically stored)
        readPage(tag: tag, page: 22, session: session) { [weak self] success, tailId in
            if success, let tailId = tailId {
                print("✅ NTAG215: Successfully read tail ID from page 22: \(tailId)")
                self?.lookupAmiiboByTailId(tailId, session: session)
            } else {
                print("⚠️ NTAG215: Failed to read page 22, trying page 21...")
                // Fallback to page 21 if page 22 fails
                self?.readPage(tag: tag, page: 21, session: session) { [weak self] success, tailId in
                    if success, let tailId = tailId {
                        print("✅ NTAG215: Successfully read tail ID from page 21: \(tailId)")
                        self?.lookupAmiiboByTailId(tailId, session: session)
                    } else {
                        print("❌ NTAG215: Failed to read Amiibo data from both pages")
                        session.invalidate(errorMessage: "Unable to read Amiibo data")
                    }
                }
            }
        }
    }
    
    private func readPage(tag: NFCMiFareTag, page: Int, session: NFCTagReaderSession, completion: @escaping (Bool, String?) -> Void) {
        let pageNumber: UInt8 = UInt8(page)
        let readCommand = Data([0x30, pageNumber]) // MiFare read command
        
        print("📱 NTAG215: Sending read command for page \(page) (0x\(String(format: "%02x", pageNumber)))")
        
        tag.sendMiFareCommand(commandPacket: readCommand) { (response: Data?, error: Error?) in
            if let error = error {
                print("❌ NTAG215: Error reading page \(page): \(error.localizedDescription)")
                completion(false, nil)
                return
            }
            
            guard let response = response, response.count >= 4 else {
                print("❌ NTAG215: Invalid response from page \(page): \(response?.count ?? 0) bytes")
                completion(false, nil)
                return
            }
            
            print("✅ NTAG215: Read page \(page) response: \(response.map { String(format: "%02x", $0) }.joined())")
            
            // Extract tail data (first 4 bytes from the response)
            let tailHex = response.prefix(4).map { String(format: "%02x", $0) }.joined()
            
            print("📱 NTAG215: Extracted tail from page \(page): \(tailHex)")
            
            completion(true, tailHex)
        }
    }
    
    
    private func lookupAmiiboByTailId(_ tailId: String, session: NFCTagReaderSession) {
        print("🔍 NTAG215: Looking up Amiibo with tail ID: \(tailId)")
        
        guard let repository = amiiboRepository else {
            print("❌ NTAG215: No repository available")
            DispatchQueue.main.async {
                session.invalidate(errorMessage: "Database not available")
            }
            return
        }
        
        // Look up the Amiibo in the database
        repository.getAmiiboByTailId(tailId) { [weak self] amiibo in
            DispatchQueue.main.async {
                if let amiibo = amiibo {
                    print("✅ NTAG215: Found Amiibo: \(amiibo.name ?? "Unknown")")
                    self?.scannedAmiibo = amiibo
                    session.alertMessage = "Amiibo scanned successfully!"
                    
                    // Navigate to Amiibo details after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        session.invalidate()
                    }
                } else {
                    print("❌ NTAG215: Amiibo not found in database")
                    self?.errorMessage = "Amiibo not found in database"
                    session.alertMessage = "Amiibo not recognized"
                    session.invalidate()
                }
            }
        }
    }
}