import AppKit

final class SpaceAnchor {
  private var window: AnchorWindow?
  private var observer: NSObjectProtocol?

  var isHolding: Bool { window != nil }

  func hold(at point: NSPoint) {
    let wasHolding = isHolding
    dropWindow()
    let window = AnchorWindow(
      contentRect: NSRect(origin: point, size: NSSize(width: 1, height: 1)),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.ignoresCycle]
    self.window = window
    if !wasHolding {
      NSApp.setActivationPolicy(.regular)
    }
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    WindowFocuser.focusApp(getpid())
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: NSApplication.didResignActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.release()
    }
  }

  func release() {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    if window != nil {
      NSApp.setActivationPolicy(.accessory)
    }
    dropWindow()
  }

  private func dropWindow() {
    window?.orderOut(nil)
    window = nil
  }
}

private final class AnchorWindow: NSWindow {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }
}
