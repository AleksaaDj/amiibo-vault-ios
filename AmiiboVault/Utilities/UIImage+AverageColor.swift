import UIKit

extension UIImage {
    /// Average color of visible pixels, with the same HSL boost Android uses.
    /// Transparent pixels are skipped so amiibo PNGs do not wash out to gray.
    var averageColor: UIColor? {
        opaqueAverageColor() ?? ciAreaAverageColor()
    }

    private func opaqueAverageColor() -> UIColor? {
        guard let cgImage else { return nil }
        let size = 50
        let bytesPerPixel = 4
        var pixels = [UInt8](repeating: 0, count: size * size * bytesPerPixel)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: size,
                    height: size,
                    bitsPerComponent: 8,
                    bytesPerRow: size * bytesPerPixel,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.clear(CGRect(x: 0, y: 0, width: size, height: size))
            context.interpolationQuality = .low
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard drawn else { return nil }

        var redSum = 0
        var greenSum = 0
        var blueSum = 0
        var count = 0
        let alphaThreshold: UInt8 = 32
        for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let alpha = pixels[index + 3]
            guard alpha >= alphaThreshold else { continue }
            let alphaValue = Int(alpha)
            redSum += Int(pixels[index]) * 255 / alphaValue
            greenSum += Int(pixels[index + 1]) * 255 / alphaValue
            blueSum += Int(pixels[index + 2]) * 255 / alphaValue
            count += 1
        }
        guard count > 0 else { return nil }
        return boostedColor(
            red: CGFloat(redSum) / CGFloat(count) / 255,
            green: CGFloat(greenSum) / CGFloat(count) / 255,
            blue: CGFloat(blueSum) / CGFloat(count) / 255
        )
    }

    private func ciAreaAverageColor() -> UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extent = inputImage.extent
        let extentVector = CIVector(
            x: extent.origin.x,
            y: extent.origin.y,
            z: extent.size.width,
            w: extent.size.height
        )
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]
        ),
              let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return boostedColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255
        )
    }

    private func boostedColor(red: CGFloat, green: CGFloat, blue: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(red: red, green: green, blue: blue, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return UIColor(
            hue: hue,
            saturation: min(saturation + 0.3, 1),
            brightness: min(brightness + 0.2, 1),
            alpha: 1
        )
    }
}
