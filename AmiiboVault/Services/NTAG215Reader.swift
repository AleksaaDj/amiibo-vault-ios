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
        
        guard NFCTagReaderSession.readingAvailable else {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "NFC is not available on this device"
            }
            return
        }
        
        
        // Clear any previous session
        nfcSession?.invalidate()
        nfcSession = nil
        
        nfcSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self, queue: nil)
        nfcSession?.alertMessage = "Hold your iPhone near an Amiibo to scan it"
        
        DispatchQueue.main.async { [weak self] in
            self?.isScanning = true
        }
        
        nfcSession?.begin()
    }
    
    func stopScanning() {
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
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isScanning = false
            
            if let nfcError = error as? NFCReaderError {
                switch nfcError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    break
                case .readerSessionInvalidationErrorSessionTimeout:
                    self.errorMessage = "Scanning timed out. Please try again."
                case .readerSessionInvalidationErrorSystemIsBusy:
                    self.errorMessage = "System is busy. Please try again."
                default:
                    self.errorMessage = "NFC Error: \(nfcError.localizedDescription)"
                }
            } else {
                self.errorMessage = "NFC Error: \(error.localizedDescription)"
            }
        }
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        guard let firstTag = tags.first else {
            session.invalidate(errorMessage: "No tags found.")
            return
        }
        session.alertMessage = "Amiibo detected! Reading data..."
        
        // Connect to the tag first
        session.connect(to: firstTag) { [weak self] (error) in
            if let error = error {
                session.invalidate(errorMessage: "Connection error: \(error.localizedDescription)")
                return
            }
            
            
            // Check if it's a MiFare tag (NTAG215 is a type of MiFare)
            if case let NFCTag.miFare(miFareTag) = firstTag {
                self?.readAmiiboData(from: miFareTag, session: session)
            } else {
                session.invalidate(errorMessage: "Invalid tag type for Amiibo.")
            }
        }
    }
    
    private func readAmiiboData(from tag: NFCMiFareTag, session: NFCTagReaderSession) {
        
        // Try to read page 22 first (where tail ID is typically stored)
        readPage(tag: tag, page: 22, session: session) { [weak self] success, tailId in
            if success, let tailId = tailId {
                self?.lookupAmiiboByTailId(tailId, session: session)
            } else {
                // Fallback to page 21 if page 22 fails
                self?.readPage(tag: tag, page: 21, session: session) { [weak self] success, tailId in
                    if success, let tailId = tailId {
                        self?.lookupAmiiboByTailId(tailId, session: session)
                    } else {
                        session.invalidate(errorMessage: "Unable to read Amiibo data")
                    }
                }
            }
        }
    }
    
    private func readPage(tag: NFCMiFareTag, page: Int, session: NFCTagReaderSession, completion: @escaping (Bool, String?) -> Void) {
        let pageNumber: UInt8 = UInt8(page)
        let readCommand = Data([0x30, pageNumber]) // MiFare read command
        
        
        tag.sendMiFareCommand(commandPacket: readCommand) { (response: Data?, error: Error?) in
            if error != nil {
                completion(false, nil)
                return
            }
            
            guard let response = response, response.count >= 4 else {
                completion(false, nil)
                return
            }
            
            
            // Extract tail data (first 4 bytes from the response)
            let tailHex = response.prefix(4).map { String(format: "%02x", $0) }.joined()
            
            
            completion(true, tailHex)
        }
    }
    
    
    private func lookupAmiiboByTailId(_ tailId: String, session: NFCTagReaderSession) {
        
        guard let repository = amiiboRepository else {
            DispatchQueue.main.async {
                session.invalidate(errorMessage: "Database not available")
            }
            return
        }
        
        // Look up the Amiibo in the database
        repository.getAmiiboByTailId(tailId) { [weak self] amiibo in
            DispatchQueue.main.async {
                if let amiibo = amiibo {
                    self?.scannedAmiibo = amiibo
                    session.alertMessage = "Amiibo scanned successfully!"
                    
                    // Navigate to Amiibo details after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        session.invalidate()
                    }
                } else {
                    self?.errorMessage = "Amiibo not found in database"
                    session.alertMessage = "Amiibo not recognized"
                    session.invalidate()
                }
            }
        }
    }
}