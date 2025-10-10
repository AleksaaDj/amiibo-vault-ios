import UIKit
import SwiftUI

class AverageColorCalculator {
    static func getAverageColor(from image: UIImage, amiiboName: String? = nil) -> Color {
        print("🔍 AverageColorCalculator: Starting Android-style calculation for image size: \(image.size)")
        
        guard let cgImage = image.cgImage else {
            print("❌ AverageColorCalculator: No CGImage available")
            return Color.gray
        }
        
        // Resize the image to 50x50 for faster processing (like Android)
        let size = CGSize(width: 50, height: 50)
        let resizedImage = image.resized(to: size)
        
        // Get pixel data
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("❌ AverageColorCalculator: Failed to create CGContext")
            return Color.gray
        }
        
        context.draw(resizedImage.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var redSum = 0
        var greenSum = 0
        var blueSum = 0
        
        // Calculate the sum of RGB values (like Android) - exclude bottom 1/4 of image
        let excludeBottomQuarter = height * 3 / 4 // Only process top 3/4 of the image
        let totalPixelsToProcess = width * excludeBottomQuarter
        
        for y in 0..<excludeBottomQuarter {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                guard pixelIndex + 2 < pixelData.count else { continue }
                
                let red = Int(pixelData[pixelIndex])
                let green = Int(pixelData[pixelIndex + 1])
                let blue = Int(pixelData[pixelIndex + 2])
                
                redSum += red
                greenSum += green
                blueSum += blue
            }
        }
        
        let pixelCount = max(totalPixelsToProcess, 1)
        let averageRed = redSum / pixelCount
        let averageGreen = greenSum / pixelCount
        let averageBlue = blueSum / pixelCount
        
        print("🔍 AverageColorCalculator: Processed \(pixelCount) pixels (top 3/4 only), average RGB - R:\(averageRed) G:\(averageGreen) B:\(averageBlue)")
        print("🔍 AverageColorCalculator: Image size: \(width)x\(height), excluded bottom: \(height - excludeBottomQuarter) pixels")
        
        // Convert average RGB to Color
        let averageColor = Color(red: Double(averageRed) / 255.0,
                                 green: Double(averageGreen) / 255.0,
                                 blue: Double(averageBlue) / 255.0)
        
        // Convert average color to HSL
        let hsl = rgbToHsl(red: Double(averageRed), green: Double(averageGreen), blue: Double(averageBlue))
        
        // Adjust HSL components (like Android)
        let adjustedHsl = (
            hue: hsl.hue + 0.2,
            saturation: min(1.0, hsl.saturation + 0.3),
            lightness: min(1.0, hsl.lightness + 0.2)
        )
        
        // Convert adjusted HSL back to RGB
        let adjustedRgb = hslToRgb(hue: adjustedHsl.hue, saturation: adjustedHsl.saturation, lightness: adjustedHsl.lightness)
        
        print("🔍 AverageColorCalculator: HSL - H:\(String(format: "%.2f", adjustedHsl.hue)) S:\(String(format: "%.2f", adjustedHsl.saturation)) L:\(String(format: "%.2f", adjustedHsl.lightness))")
        print("🔍 AverageColorCalculator: Adjusted RGB - R:\(Int(adjustedRgb.red)) G:\(Int(adjustedRgb.green)) B:\(Int(adjustedRgb.blue))")
        
        let finalColor = Color(red: adjustedRgb.red / 255.0,
                               green: adjustedRgb.green / 255.0,
                               blue: adjustedRgb.blue / 255.0)
        
        print("✅ AverageColorCalculator: Final color calculated: \(finalColor)")
        return finalColor
    }
    
    // Fallback color palette for when image analysis fails
    private static func getFallbackColor() -> Color {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .mint, .teal, .cyan, .blue, .indigo, .purple, .pink, .brown
        ]
        let randomIndex = Int.random(in: 0..<colors.count)
        return colors[randomIndex]
    }
    
    // Generate a unique color based on Amiibo name (for consistent colors)
    static func getColorForAmiibo(name: String) -> Color {
        let hash = name.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        let saturation = 0.7 + Double(abs(hash % 30)) / 100.0 // 0.7 to 1.0
        let lightness = 0.5 + Double(abs(hash % 20)) / 100.0 // 0.5 to 0.7
        
        return Color(hue: hue, saturation: saturation, brightness: lightness)
    }
    
    private static func rgbToHsl(red: Double, green: Double, blue: Double) -> (hue: Double, saturation: Double, lightness: Double) {
        let r = red / 255.0
        let g = green / 255.0
        let b = blue / 255.0

        let max = Swift.max(r, g, b)
        let min = Swift.min(r, g, b)
        let delta = max - min

        var hue: Double = 0
        var saturation: Double = 0
        let lightness = (max + min) / 2

        if delta != 0 {
            saturation = lightness > 0.5 ? delta / (2 - max - min) : delta / (max + min)

            switch max {
            case r:
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            case g:
                hue = (b - r) / delta + 2
            case b:
                hue = (r - g) / delta + 4
            default:
                break
            }
            hue /= 6
        }
        
        return (hue: hue, saturation: saturation, lightness: lightness)
    }
    
    private static func hslToRgb(hue: Double, saturation: Double, lightness: Double) -> (red: Double, green: Double, blue: Double) {
        let h = hue
        let s = saturation
        let l = lightness

        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2

        var r: Double = 0
        var g: Double = 0
        var b: Double = 0

        if h < 1/6 {
            r = c; g = x; b = 0
        } else if h < 2/6 {
            r = x; g = c; b = 0
        } else if h < 3/6 {
            r = 0; g = c; b = x
        } else if h < 4/6 {
            r = 0; g = x; b = c
        } else if h < 5/6 {
            r = x; g = 0; b = c
        } else {
            r = c; g = 0; b = x
        }
        
        return (
            red: (r + m) * 255,
            green: (g + m) * 255,
            blue: (b + m) * 255
        )
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
