import AppKit

enum TailSide {
  case left
  case right
  case top
  case bottom
}

final class GreetingBubble: NSPanel {
  private static let gap: CGFloat = 4
  private static let fadeIn: TimeInterval = 0.15
  private static let stay: TimeInterval = 1.8
  private static let fadeOut: TimeInterval = 0.2

  private let bubbleView = BubbleView()
  private var generation = 0

  init() {
    super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    ignoresMouseEvents = true
    level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    contentView = bubbleView
  }

  func show(_ text: String, near anchor: NSRect, on screen: NSScreen) {
    generation += 1
    let id = generation
    let placement = place(text, near: anchor, in: screen.visibleFrame)
    bubbleView.text = text
    bubbleView.tail = placement.side
    bubbleView.tailOffset = placement.tailOffset
    setFrame(placement.frame, display: true)
    bubbleView.needsDisplay = true
    invalidateShadow()
    if !isVisible {
      alphaValue = 0
    }
    orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.fadeIn
      animator().alphaValue = 1
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.fadeIn + Self.stay) { [weak self] in
      guard let self, self.generation == id else { return }
      self.hide()
    }
  }

  func hide() {
    let id = generation
    NSAnimationContext.runAnimationGroup({ context in
      context.duration = Self.fadeOut
      animator().alphaValue = 0
    }, completionHandler: { [weak self] in
      guard let self, self.generation == id else { return }
      self.orderOut(nil)
    })
  }

  private func place(_ text: String, near anchor: NSRect, in visible: NSRect) -> (frame: NSRect, side: TailSide, tailOffset: CGFloat) {
    let body = BubbleView.bodySize(for: text)
    let tail = BubbleView.tailSize
    let point = NSPoint(x: anchor.midX, y: anchor.midY)

    func frame(_ side: TailSide) -> NSRect {
      switch side {
      case .right:
        let size = NSSize(width: body.width + tail, height: body.height)
        return NSRect(x: anchor.minX - Self.gap - size.width, y: point.y - size.height / 2, width: size.width, height: size.height)
      case .left:
        let size = NSSize(width: body.width + tail, height: body.height)
        return NSRect(x: anchor.maxX + Self.gap, y: point.y - size.height / 2, width: size.width, height: size.height)
      case .top:
        let size = NSSize(width: body.width, height: body.height + tail)
        return NSRect(x: point.x - size.width / 2, y: anchor.minY - Self.gap - size.height, width: size.width, height: size.height)
      case .bottom:
        let size = NSSize(width: body.width, height: body.height + tail)
        return NSRect(x: point.x - size.width / 2, y: anchor.maxY + Self.gap, width: size.width, height: size.height)
      }
    }

    func fits(_ rect: NSRect, _ side: TailSide) -> Bool {
      switch side {
      case .right: return rect.minX >= visible.minX
      case .left: return rect.maxX <= visible.maxX
      case .top: return rect.minY >= visible.minY
      case .bottom: return rect.maxY <= visible.maxY
      }
    }

    let sides: [TailSide] = [.right, .top, .left, .bottom]
    let side = sides.first { fits(frame($0), $0) } ?? .right
    var rect = frame(side)
    rect.origin.x = min(max(rect.minX, visible.minX), visible.maxX - rect.width)
    rect.origin.y = min(max(rect.minY, visible.minY), visible.maxY - rect.height)
    let tailOffset = side == .left || side == .right ? point.y - rect.minY : point.x - rect.minX
    return (rect, side, tailOffset)
  }
}

final class BubbleView: NSView {
  static let font = NSFont.systemFont(ofSize: 12)
  static let tailSize: CGFloat = 6
  private static let padding = NSSize(width: 8, height: 5)
  private static let radius: CGFloat = 8
  private static let tailHalfWidth: CGFloat = 5

  var text = ""
  var tail: TailSide = .right
  var tailOffset: CGFloat = 0

  static func bodySize(for text: String) -> NSSize {
    let size = (text as NSString).size(withAttributes: [.font: font])
    return NSSize(width: ceil(size.width) + padding.width * 2, height: ceil(size.height) + padding.height * 2)
  }

  override func draw(_ dirtyRect: NSRect) {
    let t = Self.tailSize
    let r = Self.radius
    let half = Self.tailHalfWidth
    var body = bounds
    switch tail {
    case .right:
      body.size.width -= t
    case .left:
      body.origin.x += t
      body.size.width -= t
    case .top:
      body.size.height -= t
    case .bottom:
      body.origin.y += t
      body.size.height -= t
    }

    let pointer = NSBezierPath()
    switch tail {
    case .right, .left:
      let y = min(max(tailOffset, body.minY + half), body.maxY - half)
      let edge = tail == .right ? body.maxX : body.minX
      let tip = tail == .right ? edge + t : edge - t
      let inset: CGFloat = tail == .right ? -1 : 1
      pointer.move(to: NSPoint(x: edge + inset, y: y - half))
      pointer.line(to: NSPoint(x: tip, y: y))
      pointer.line(to: NSPoint(x: edge + inset, y: y + half))
    case .top, .bottom:
      let x = min(max(tailOffset, body.minX + r), body.maxX - r)
      let edge = tail == .top ? body.maxY : body.minY
      let tip = tail == .top ? edge + t : edge - t
      let inset: CGFloat = tail == .top ? -1 : 1
      pointer.move(to: NSPoint(x: x - half, y: edge + inset))
      pointer.line(to: NSPoint(x: x, y: tip))
      pointer.line(to: NSPoint(x: x + half, y: edge + inset))
    }
    pointer.close()

    NSColor.textBackgroundColor.setFill()
    NSBezierPath(roundedRect: body, xRadius: r, yRadius: r).fill()
    pointer.fill()

    let attributes: [NSAttributedString.Key: Any] = [.font: Self.font, .foregroundColor: NSColor.labelColor]
    let size = (text as NSString).size(withAttributes: attributes)
    let origin = NSPoint(x: body.midX - size.width / 2, y: body.midY - size.height / 2)
    (text as NSString).draw(at: origin, withAttributes: attributes)
  }
}
