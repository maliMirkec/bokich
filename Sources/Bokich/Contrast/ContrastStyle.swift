import AppKit

struct ContrastStyle {
  var borderColor: NSColor
  var borderWidth: CGFloat
  var shadowColor: NSColor
  var shadowOpacity: Float
  var shadowRadius: CGFloat
  var shadowOffset: CGSize

  static func make(background: NSColor?, blob: NSColor) -> ContrastStyle {
    var style = shadow(for: blob)
    guard let background else {
      style.borderColor = NSColor.black.withAlphaComponent(0.4)
      style.borderWidth = 1
      return style
    }
    if Palette.luminance(background) > 0.5 {
      style.borderColor = NSColor.black.withAlphaComponent(0.35)
    } else {
      style.borderColor = NSColor.white.withAlphaComponent(0.6)
    }
    style.borderWidth = Palette.contrast(blob, background) < 1.5 ? 2 : 1
    return style
  }

  private static func shadow(for blob: NSColor) -> ContrastStyle {
    if Palette.isLight(blob) {
      return ContrastStyle(
        borderColor: .clear,
        borderWidth: 1,
        shadowColor: .black,
        shadowOpacity: 0.35,
        shadowRadius: 4,
        shadowOffset: CGSize(width: 0, height: -1)
      )
    }
    return ContrastStyle(
      borderColor: .clear,
      borderWidth: 1,
      shadowColor: .white,
      shadowOpacity: 0.45,
      shadowRadius: 5,
      shadowOffset: .zero
    )
  }
}
