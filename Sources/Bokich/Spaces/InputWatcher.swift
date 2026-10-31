import AppKit
import Carbon

struct Click {
  let time: Date
  let windowID: CGWindowID
  let location: CGPoint
}

struct KeyPress {
  private static let leaveKeys: Set<UInt16> = [12, 13, 4, 46]
  private static let enterKeys: Set<UInt16> = [36, 76]
  private static let tabKey: UInt16 = 48

  let time: Date
  let keyCode: UInt16
  let flags: NSEvent.ModifierFlags

  var isLeaveShortcut: Bool {
    flags.contains(.command) && Self.leaveKeys.contains(keyCode)
  }

  var isEnter: Bool {
    Self.enterKeys.contains(keyCode)
  }

  var isCommandTab: Bool {
    flags.contains(.command) && keyCode == Self.tabKey
  }
}

final class InputWatcher {
  static let ownEventTag: Int64 = 0x424F4B49
  private static let switchModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
  private static let blindMargin: TimeInterval = 0.1
  private static let staleHold: TimeInterval = 10
  private static let hiddenKeyAge: TimeInterval = 0.3

  private(set) var lastKeyPress: KeyPress?
  private(set) var lastClick: Click?
  private var lastSwitchKey: Date?
  private var lastSeenKey: Date?
  private var lastSeenKeyDown: Date?
  private var modifierDown: Date?
  private var sawModifiedKey = false
  private var monitors: [Any] = []

  func isLastKeyDown(_ key: KeyPress) -> Bool {
    let sinceKeyDown = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    return sinceKeyDown > Date().timeIntervalSince(key.time) - 0.1
  }

  func isSwitchKey(near time: Date, within window: TimeInterval) -> Bool {
    if let lastSwitchKey, abs(time.timeIntervalSince(lastSwitchKey)) < window { return true }
    let now = Date()
    let sinceFlags = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .flagsChanged)
    let sinceKeyDown = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    let sinceSeen = lastSeenKey.map { now.timeIntervalSince($0) } ?? .infinity
    let sinceSeenKeyDown = lastSeenKeyDown.map { now.timeIntervalSince($0) } ?? .infinity
    let secure = IsSecureEventInputEnabled()
    let keyDownAge = sinceKeyDown - now.timeIntervalSince(time)
    if !secure, sinceKeyDown >= Self.hiddenKeyAge, sinceKeyDown < sinceSeenKeyDown - Self.blindMargin, abs(keyDownAge) < window {
      Log.input.debug("hidden key down \(keyDownAge, privacy: .public)s before activation, last seen key down \(sinceSeenKeyDown, privacy: .public)s ago")
      return true
    }
    guard min(sinceFlags, sinceKeyDown) < sinceSeen - Self.blindMargin else { return false }
    let flagsAge = sinceFlags - now.timeIntervalSince(time)
    Log.input.debug("keys hidden from Bokich, modifier \(flagsAge, privacy: .public)s ago, key down \(sinceKeyDown, privacy: .public)s ago, last seen \(sinceSeen, privacy: .public)s ago, secure input \(secure, privacy: .public)")
    return sinceFlags <= sinceKeyDown && abs(flagsAge) < window
  }

  func start() {
    guard monitors.isEmpty else { return }
    let keys = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
      self?.key(event)
    }
    let ownKeys = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
      self?.key(event)
      return event
    }
    let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { [weak self] _ in
      self?.lastClick = Self.click()
    }
    monitors = [keys, ownKeys, clicks].compactMap { $0 }
    Log.input.debug("input monitors started: \(self.monitors.count, privacy: .public)")
  }

  func stop() {
    monitors.forEach(NSEvent.removeMonitor)
    monitors = []
    Log.input.debug("input monitors stopped")
  }

  private func key(_ event: NSEvent) {
    let now = Date()
    lastSeenKey = now
    guard event.cgEvent?.getIntegerValueField(.eventSourceUserData) != Self.ownEventTag else { return }
    if event.type == .flagsChanged {
      modifiersChanged(event.modifierFlags.intersection(Self.switchModifiers), at: now)
      return
    }
    if modifierDown != nil { sawModifiedKey = true }
    lastSeenKeyDown = now
    let press = KeyPress(time: now, keyCode: event.keyCode, flags: event.modifierFlags)
    lastKeyPress = press
    if press.isCommandTab { Log.input.debug("saw Cmd+Tab") }
    if press.isEnter || press.isCommandTab { lastSwitchKey = now }
  }

  private func modifiersChanged(_ held: NSEvent.ModifierFlags, at now: Date) {
    guard held.isEmpty else {
      if modifierDown == nil {
        modifierDown = now
        sawModifiedKey = false
      }
      return
    }
    defer { modifierDown = nil }
    guard let down = modifierDown, now.timeIntervalSince(down) < Self.staleHold, !sawModifiedKey else { return }
    let sinceKeyDown = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    let heldFor = now.timeIntervalSince(down)
    Log.input.debug("modifiers released after \(heldFor, privacy: .public)s, key down \(sinceKeyDown, privacy: .public)s ago")
    if sinceKeyDown < heldFor {
      lastSwitchKey = now
    }
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
