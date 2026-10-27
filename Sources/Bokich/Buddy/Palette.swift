import AppKit

struct Swatch {
  let color: NSColor
  let face: NSColor
}

enum Palette {
  static let ink = NSColor(hex: "#161616")
  static let peach = NSColor(hex: "#FFD6A5")
  static let lemon = NSColor(hex: "#FDFFB6")
  static let mint = NSColor(hex: "#CAFFBF")
  static let sky = NSColor(hex: "#9BF6FF")
  static let tongue = NSColor(hex: "#FF7A90")

  static let swatches: [Swatch] = [
    Swatch(color: peach, face: ink),
    Swatch(color: lemon, face: ink),
    Swatch(color: mint, face: ink),
    Swatch(color: sky, face: ink),
    Swatch(color: NSColor(hex: "#A0C4FF"), face: ink),
    Swatch(color: NSColor(hex: "#BDB2FF"), face: ink),
    Swatch(color: NSColor(hex: "#FFC6FF"), face: ink),
    Swatch(color: NSColor(hex: "#FFADAD"), face: ink),
    Swatch(color: NSColor(hex: "#4F4A85"), face: peach),
    Swatch(color: NSColor(hex: "#355C7D"), face: lemon),
    Swatch(color: NSColor(hex: "#356B55"), face: mint),
    Swatch(color: NSColor(hex: "#7D3F5C"), face: mint),
    Swatch(color: NSColor(hex: "#245E63"), face: peach),
    Swatch(color: NSColor(hex: "#6A3F7E"), face: lemon),
    Swatch(color: NSColor(hex: "#7A4B3A"), face: sky)
  ]

  static func isLight(_ color: NSColor) -> Bool {
    luminance(color) > 0.3
  }

  static func luminance(_ color: NSColor) -> CGFloat {
    guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
    func linear(_ value: CGFloat) -> CGFloat {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(rgb.redComponent) + 0.7152 * linear(rgb.greenComponent) + 0.0722 * linear(rgb.blueComponent)
  }

  static func contrast(_ a: NSColor, _ b: NSColor) -> CGFloat {
    let la = luminance(a)
    let lb = luminance(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
  }
}

extension NSColor {
  convenience init(hex: String) {
    let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
    self.init(
      srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
  }
}
