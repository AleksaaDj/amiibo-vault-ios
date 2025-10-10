import Foundation
import UIKit

class ImageCacheService {
    static let shared = ImageCacheService()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        // Configure cache
        cache.countLimit = 200 // Maximum 200 images in memory
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB memory limit
    }
    
    func getImage(from url: String) -> UIImage? {
        let key = NSString(string: url)
        return cache.object(forKey: key)
    }
    
    func setImage(_ image: UIImage, for url: String) {
        let key = NSString(string: url)
        cache.setObject(image, forKey: key)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
}