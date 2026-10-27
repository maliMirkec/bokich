import AppKit

struct BlobShape: Codable, Equatable {
  static let pointCount = 7

  var radii: [CGFloat]
  var angleJitter: [CGFloat]
  var colorIndex: Int

  var isValid: Bool {
    radii.count == Self.pointCount && angleJitter.count == Self.pointCount
  }

  var swatch: Swatch {
    Palette.swatches[abs(colorIndex) % Palette.swatches.count]
  }

  var color: NSColor {
    swatch.color
  }

  static func random(previousColor: Int? = nil) -> BlobShape {
    let step = 2 * CGFloat.pi / CGFloat(pointCount)
    let radii = (0..<pointCount).map { _ in CGFloat.random(in: 0.82...1.05) }
    let jitter = (0..<pointCount).map { _ in CGFloat.random(in: -0.25...0.25) * step }
    var color = Int.random(in: 0..<Palette.swatches.count)
    if let previousColor, Palette.swatches.count > 1 {
      while color == previousColor {
        color = Int.random(in: 0..<Palette.swatches.count)
      }
    }
    return BlobShape(radii: radii, angleJitter: jitter, colorIndex: color)
  }

  func path(center: CGPoint, baseRadius: CGFloat, tension: CGFloat = 1) -> CGPath {
    let count = Self.pointCount
    let step = 2 * CGFloat.pi / CGFloat(count)
    let points = (0..<count).map { index -> CGPoint in
      let angle = CGFloat(index) * step + angleJitter[index]
      let radius = baseRadius * radii[index]
      return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
    return Self.smoothPath(points, tension: tension)
  }

  static func smoothPath(_ points: [CGPoint], tension: CGFloat = 1) -> CGPath {
    let count = points.count
    let path = CGMutablePath()
    path.move(to: points[0])
    for index in 0..<count {
      let p0 = points[(index - 1 + count) % count]
      let p1 = points[index]
      let p2 = points[(index + 1) % count]
      let p3 = points[(index + 2) % count]
      let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6 * tension, y: p1.y + (p2.y - p0.y) / 6 * tension)
      let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6 * tension, y: p2.y - (p3.y - p1.y) / 6 * tension)
      path.addCurve(to: p2, control1: c1, control2: c2)
    }
    path.closeSubpath()
    return path
  }
}
