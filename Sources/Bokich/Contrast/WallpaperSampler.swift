import AppKit
import ImageIO
import UniformTypeIdentifiers

final class WallpaperSampler {
  private static let maxPixelSize = 512
  private static let expand: CGFloat = 8
  private static let sampleSize = 8

  private struct CacheKey: Equatable {
    var signature: String
    var screenID: Int
    var frame: NSRect
  }

  private var lastKey: CacheKey?
  private var lastColor: NSColor?

  func signature(for screen: NSScreen) -> String {
    let url = NSWorkspace.shared.desktopImageURL(for: screen)?.path ?? ""
    let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
    let scaling = (options[.imageScaling] as? NSNumber)?.intValue ?? -1
    let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? false
    let fill = (options[.fillColor] as? NSColor)?.description ?? ""
    return "\(url)|\(scaling)|\(clipping)|\(fill)"
  }

  func sample(frame: NSRect, screen: NSScreen) -> NSColor? {
    let key = CacheKey(signature: signature(for: screen), screenID: screen.displayID ?? 0, frame: frame)
    if key == lastKey {
      return lastColor
    }
    let color = compute(frame: frame, screen: screen)
    lastKey = key
    lastColor = color
    return color
  }

  private func compute(frame: NSRect, screen: NSScreen) -> NSColor? {
    guard let url = NSWorkspace.shared.desktopImageURL(for: screen),
          isStillImage(url),
          FileManager.default.isReadableFile(atPath: url.path),
          let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          CGImageSourceGetCount(source) == 1 else { return nil }
    let thumbnailOptions: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: Self.maxPixelSize
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else { return nil }

    let options = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
    let fillColor = (options[.fillColor] as? NSColor) ?? .black
    let drawn = drawnRect(image: image, source: source, options: options, screen: screen)
    let region = frame
      .offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
      .insetBy(dx: -Self.expand, dy: -Self.expand)
    return averageColor(image: image, drawn: drawn, region: region, fill: fillColor)
  }

  private func isStillImage(_ url: URL) -> Bool {
    let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
    if values?.isDirectory == true { return false }
    if let type = values?.contentType, type.conforms(to: .movie) || type.conforms(to: .audiovisualContent) {
      return false
    }
    return true
  }

  private func drawnRect(image: CGImage, source: CGImageSource, options: [NSWorkspace.DesktopImageOptionKey: Any], screen: NSScreen) -> NSRect {
    let screenSize = screen.frame.size
    let imageSize = NSSize(width: image.width, height: image.height)
    let scaling = (options[.imageScaling] as? NSNumber).flatMap { NSImageScaling(rawValue: $0.uintValue) } ?? .scaleProportionallyUpOrDown
    let clipping = (options[.allowClipping] as? NSNumber)?.boolValue ?? true
    var size: NSSize
    switch scaling {
    case .scaleAxesIndependently:
      size = screenSize
    case .scaleNone:
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
      let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? imageSize.width
      let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? imageSize.height
      let scale = screen.backingScaleFactor
      size = NSSize(width: width / scale, height: height / scale)
    default:
      let sx = screenSize.width / imageSize.width
      let sy = screenSize.height / imageSize.height
      let scale = clipping && scaling == .scaleProportionallyUpOrDown ? max(sx, sy) : min(sx, sy)
      size = NSSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }
    return NSRect(
      x: (screenSize.width - size.width) / 2,
      y: (screenSize.height - size.height) / 2,
      width: size.width,
      height: size.height
    )
  }

  private func averageColor(image: CGImage, drawn: NSRect, region: NSRect, fill: NSColor) -> NSColor? {
    let side = Self.sampleSize
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: side * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { return nil }
    context.interpolationQuality = .medium
    context.scaleBy(x: CGFloat(side) / region.width, y: CGFloat(side) / region.height)
    context.translateBy(x: -region.minX, y: -region.minY)
    context.setFillColor((fill.usingColorSpace(.sRGB) ?? fill).cgColor)
    context.fill(region)
    context.draw(image, in: drawn)
    guard let data = context.data else { return nil }
    let pixels = data.bindMemory(to: UInt8.self, capacity: side * side * 4)
    var red = 0.0
    var green = 0.0
    var blue = 0.0
    let count = side * side
    for index in 0..<count {
      red += Double(pixels[index * 4])
      green += Double(pixels[index * 4 + 1])
      blue += Double(pixels[index * 4 + 2])
    }
    let total = Double(count) * 255
    return NSColor(srgbRed: red / total, green: green / total, blue: blue / total, alpha: 1)
  }
}
