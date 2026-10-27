import AppKit

final class BuddyWindow: NSPanel {
  static let size: CGFloat = 44
  private static let rightInset: CGFloat = 12
  private static let topInset: CGFloat = 8

  private let buddyView: BuddyView
  private let bubble = GreetingBubble()
  private let reactions = Reactions()
  private let sampler = WallpaperSampler()
  private var wallpaperSignature: String?
  private var wallpaperTimer: Timer?

  init() {
    let frame = NSRect(x: 0, y: 0, width: Self.size, height: Self.size)
    buddyView = BuddyView(frame: frame)
    super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
    backgroundColor = .clear
    isOpaque = false
    hasShadow = false
    level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    contentView = buddyView
    buddyView.onDragStart = { [weak self] in
      self?.bubble.hide()
    }
    buddyView.onDragEnd = { [weak self] in
      self?.dragEnded()
    }
    buddyView.onClick = { [weak self] in
      self?.react()
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screensChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(spaceChanged),
      name: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil
    )
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(themeChanged),
      name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
      object: nil
    )
    wallpaperTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      self?.checkWallpaper()
    }
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  func wink() {
    buddyView.wink()
  }

  func setVisible(_ visible: Bool) {
    if visible {
      show()
    } else {
      bubble.orderOut(nil)
      orderOut(nil)
    }
  }

  func show() {
    restorePosition()
    orderFrontRegardless()
    resample()
  }

  func resetPosition() {
    Settings.position = nil
    restorePosition()
    resample()
  }

  func setEnabled(_ enabled: Bool) {
    buddyView.isOff = !enabled
    guard isVisible else { return }
    if enabled { buddyView.showFace(.happySquint) }
    say(enabled ? "Bokich on" : "Bokich off")
  }

  private func say(_ text: String) {
    guard let screen = currentScreen() else { return }
    let inset = (Self.size - BuddyView.blobSize) / 2
    bubble.show(text, near: frame.insetBy(dx: inset, dy: inset), on: screen)
  }

  private func react() {
    say(reactions.nextGreeting())
    switch reactions.nextExtra() {
    case .face(let expression):
      buddyView.showFace(expression)
    case .squish:
      buddyView.bounce()
    case nil:
      break
    }
  }

  private func restorePosition() {
    let saved = Settings.position
    let screens = NSScreen.screens
    let savedScreen = saved.flatMap { position in screens.first { $0.displayID == position.screenID } }
    guard let screen = savedScreen ?? NSScreen.main ?? screens.first else { return }
    let origin: NSPoint
    if let saved {
      origin = NSPoint(
        x: screen.frame.maxX - saved.offsetX - Self.size,
        y: screen.frame.maxY - saved.offsetY - Self.size
      )
    } else {
      let visible = screen.visibleFrame
      origin = NSPoint(
        x: visible.maxX - Self.rightInset - Self.size,
        y: visible.maxY - Self.topInset - Self.size
      )
    }
    setFrameOrigin(clamped(origin, in: screen))
  }

  private func dragEnded() {
    guard let screen = currentScreen() else { return }
    setFrameOrigin(clamped(frame.origin, in: screen))
    resample()
    guard let id = screen.displayID else { return }
    Settings.position = BuddyPosition(
      screenID: id,
      offsetX: screen.frame.maxX - frame.maxX,
      offsetY: screen.frame.maxY - frame.maxY
    )
  }

  private func currentScreen() -> NSScreen? {
    let center = NSPoint(x: frame.midX, y: frame.midY)
    return NSScreen.screens.first { $0.frame.contains(center) } ?? screen ?? NSScreen.main
  }

  private func clamped(_ origin: NSPoint, in screen: NSScreen) -> NSPoint {
    let visible = screen.visibleFrame
    return NSPoint(
      x: min(max(origin.x, visible.minX), visible.maxX - Self.size),
      y: min(max(origin.y, visible.minY), visible.maxY - Self.size)
    )
  }

  private func resample() {
    guard let screen = currentScreen() else { return }
    wallpaperSignature = sampler.signature(for: screen)
    buddyView.setBackground(sampler.sample(frame: frame, screen: screen))
  }

  private func checkWallpaper() {
    guard let screen = currentScreen(), sampler.signature(for: screen) != wallpaperSignature else { return }
    resample()
  }

  @objc private func screensChanged() {
    restorePosition()
    resample()
  }

  @objc private func spaceChanged() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.resample()
    }
  }

  @objc private func themeChanged() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.resample()
    }
  }
}

extension NSScreen {
  var displayID: Int? {
    (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue
  }
}
