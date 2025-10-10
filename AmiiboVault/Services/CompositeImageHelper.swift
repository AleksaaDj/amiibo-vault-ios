import Foundation
import UIKit
import Photos

class CompositeImageHelper {
    
    private let targetWidth: CGFloat = 1750
    private let targetHeight: CGFloat = 1480
    private let padding: CGFloat = 10
    private let topBottomPadding: CGFloat = 190 // Matching Android exactly
    
    func createAndSaveCompositeImage(amiiboList: [Amiibo], completion: @escaping (Bool) -> Void) {
        
        // Load images asynchronously
        loadAmiiboImages(amiiboList: amiiboList) { images in
            guard !images.isEmpty else {
                completion(false)
                return
            }
            
            let compositeImage = self.createAdaptiveGridImage(images: images)
            self.saveImageToPhotos(compositeImage) { success in
                completion(success)
            }
        }
    }
    
    private func loadAmiiboImages(amiiboList: [Amiibo], completion: @escaping ([UIImage]) -> Void) {
        let group = DispatchGroup()
        var images: [UIImage] = []
        let imagesQueue = DispatchQueue(label: "images.sync", attributes: .concurrent)
        
        for amiibo in amiiboList {
            
            if let imageUrl = URL(string: amiibo.image) {
                group.enter()
                downloadImage(from: imageUrl) { downloadedImage in
                    if let image = downloadedImage {
                        imagesQueue.async(flags: .barrier) {
                            images.append(image)
                        }
                    }
                    group.leave()
                }
            } else {
            }
        }
        
        group.notify(queue: .main) {
            imagesQueue.sync {
                completion(images)
            }
        }
    }
    
    private func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if error != nil {
                completion(nil)
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            
            completion(image)
        }.resume()
    }
    
    private func createAdaptiveGridImage(images: [UIImage]) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: targetHeight))
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Draw background image
            if let backgroundImage = UIImage(named: "collection_generated_background") {
                // Scale background to fit target size
                let backgroundRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
                backgroundImage.draw(in: backgroundRect)
            } else {
                // Fallback to black background if image not found
                cgContext.setFillColor(UIColor.black.cgColor)
                cgContext.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
            }
            
            // Calculate grid layout
            let columns = calculateOptimalColumns(totalImages: images.count)
            let rows = Int(ceil(Double(images.count) / Double(columns)))
            
            let maxCellWidth = (targetWidth - CGFloat(columns + 1) * padding) / CGFloat(columns)
            let maxCellHeight = (targetHeight - 2 * topBottomPadding - CGFloat(rows + 1) * padding) / CGFloat(rows)
            let cellSize = min(maxCellWidth, maxCellHeight)
            
            let totalGridWidth = CGFloat(columns) * cellSize + CGFloat(columns - 1) * padding
            let totalGridHeight = CGFloat(rows) * cellSize + CGFloat(rows - 1) * padding
            
            let horizontalOffset = (targetWidth - totalGridWidth) / 2
            let verticalOffset = (targetHeight - totalGridHeight) / 2
            
            // Draw images
            for (index, image) in images.enumerated() {
                let row = index / columns
                let col = index % columns
                
                let left = horizontalOffset + CGFloat(col) * (cellSize + padding)
                let top = verticalOffset + CGFloat(row) * (cellSize + padding)
                
                let targetRect = CGRect(x: left, y: top, width: cellSize, height: cellSize)
                drawScaledImage(image: image, in: targetRect, context: cgContext)
            }
        }
    }
    
    private func calculateOptimalColumns(totalImages: Int) -> Int {
        let estimatedCellWidth: CGFloat = {
            switch totalImages {
            case 0...20: return 300
            case 21...50: return 175
            case 51...100: return 125
            case 101...300: return 75
            case 301...500: return 65
            case 501...600: return 50
            case 601...800: return 40
            default: return 30
            }
        }()
        
        let maxColumnsBasedOnWidth = Int((targetWidth + padding) / (estimatedCellWidth + padding))
        return min(totalImages, maxColumnsBasedOnWidth)
    }
    
    private func drawScaledImage(image: UIImage, in targetRect: CGRect, context: CGContext) {
        let aspectRatio = image.size.width / image.size.height
        let targetRatio = targetRect.width / targetRect.height
        
        let (width, height): (CGFloat, CGFloat)
        if aspectRatio > targetRatio {
            width = targetRect.width
            height = targetRect.width / aspectRatio
        } else {
            width = targetRect.height * aspectRatio
            height = targetRect.height
        }
        
        let left = targetRect.minX + (targetRect.width - width) / 2
        let top = targetRect.minY + (targetRect.height - height) / 2
        
        let scaledRect = CGRect(x: left, y: top, width: width, height: height)
        
        context.saveGState()
        
        image.draw(in: scaledRect)
        
        context.restoreGState()
    }
    
    private func saveImageToPhotos(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            DispatchQueue.main.async {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }, completionHandler: { success, error in
                    completion(success)
                })
            }
        }
    }
}
