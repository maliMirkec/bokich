import AppKit

struct Click {
  let time: Date
  let windowID: CGWindowID
  let location: CGPoint
}

struct KeyPress {
  private static let leaveKeys: Set<UInt16> = [12, 13, 4, 46]

  let time: Date
  let keyCode: UInt16
  let flags: NSEvent.ModifierFlags

  var isLeaveShortcut: Bool {
    flags.contains(.command) && Self.leaveKeys.contains(keyCode)
  }
}

final class InputWatcher {
  private(set) var lastKeyPress: KeyPress?
  private(set) var lastClick: Click?
  private var monitors: [Any] = []

  var secondsSinceKey: TimeInterval {
    let types: [CGEventType] = [.keyDown, .flagsChanged]
    return types.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? .infinity
  }

  func isLastKeyDown(_ key: KeyPress) -> Bool {
    let sinceKeyDown = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    return sinceKeyDown > Date().timeIntervalSince(key.time) - 0.1
  }

  func start() {
    guard monitors.isEmpty else { return }
    let keys = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.lastKeyPress = KeyPress(time: Date(), keyCode: event.keyCode, flags: event.modifierFlags)
    }
    let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] _ in
      self?.lastClick = Self.click()
    }
    monitors = [keys, clicks].compactMap { $0 }
    Log.input.debug("input monitors started: \(self.monitors.count, privacy: .public)")
  }

  func stop() {
    monitors.forEach(NSEvent.removeMonitor)
    monitors = []
    Log.input.debug("input monitors stopped")
  }

  private static func click() -> Click {
    let mouse = NSEvent.mouseLocation
    let windowID = NSWindow.windowNumber(at: mouse, belowWindowWithWindowNumber: 0)
    let height = NSScreen.screens.first?.frame.height ?? 0
    return Click(
      time: Date(),
      windowID: CGWindowID(max(windowID, 0)),
      location: CGPoint(x: mouse.x, y: height - mouse.y)
    )
  }
}
