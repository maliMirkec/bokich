import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func hex(_ value: UInt32) -> NSColor {
  NSColor(
    srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
    green: CGFloat((value >> 8) & 0xFF) / 255,
    blue: CGFloat(value & 0xFF) / 255,
    alpha: 1
  )
}

func smoothPath(_ points: [CGPoint]) -> NSBezierPath {
  let path = NSBezierPath()
  path.move(to: points[0])
  for i in 0..<points.count {
    let p0 = points[(i - 1 + points.count) % points.count]
    let p1 = points[i]
    let p2 = points[(i + 1) % points.count]
    let p3 = points[(i + 2) % points.count]
    let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
    let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
    path.curve(to: p2, controlPoint1: c1, controlPoint2: c2)
  }
  path.close()
  return path
}

func draw(side: CGFloat) {
  let s = side / 1024
  func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: (512 + (x - 9.2) * 60) * s, y: (512 + (y - 9.2) * 60) * s)
  }
  let outline = [
    point(7.2, 16), point(12.6, 15.6), point(16.2, 11.6), point(15.4, 6.2),
    point(11.8, 2.4), point(6, 2.6), point(2.2, 6.4), point(2.4, 11.8)
  ]
  let blob = smoothPath(outline)
  NSGraphicsContext.saveGraphicsState()
  let shadow = NSShadow()
  shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
  shadow.shadowBlurRadius = 36 * s
  shadow.shadowOffset = NSSize(width: 0, height: -16 * s)
  shadow.set()
  hex(0xFFC48A).setFill()
  blob.fill()
  NSGraphicsContext.restoreGraphicsState()
  NSGradient(starting: hex(0xFFE2BE), ending: hex(0xFFC48A))?.draw(in: blob, angle: -90)
  hex(0xE8A86A).setStroke()
  blob.lineWidth = 8 * s
  blob.stroke()

  hex(0x161616).setFill()
  for x: CGFloat in [7.3, 10.7] {
    let origin = point(x - 0.9, 9.8)
    NSBezierPath(ovalIn: NSRect(x: origin.x, y: origin.y, width: 1.8 * 60 * s, height: 2.8 * 60 * s)).fill()
  }
  hex(0x161616).setStroke()
  let mouth = NSBezierPath()
  mouth.move(to: point(7, 7.6))
  mouth.curve(to: point(11, 7.6), controlPoint1: point(8.1, 6), controlPoint2: point(9.9, 6))
  mouth.lineWidth = 1.2 * 60 * s
  mouth.lineCapStyle = .round
  mouth.stroke()
}

func write(pixels: Int, name: String) {
  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ) else { return }
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  draw(side: CGFloat(pixels))
  NSGraphicsContext.restoreGraphicsState()
  let data = rep.representation(using: .png, properties: [:])
  try? data?.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

for size in [16, 32, 128, 256, 512] {
  write(pixels: size, name: "icon_\(size)x\(size)")
  write(pixels: size * 2, name: "icon_\(size)x\(size)@2x")
}
