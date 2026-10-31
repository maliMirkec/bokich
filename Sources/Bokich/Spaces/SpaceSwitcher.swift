import AppKit

struct SpaceKey {
  let keyCode: CGKeyCode
  let flags: CGEventFlags

  func post() {
    let source = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
      let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down)
      event?.flags = flags
      event?.setIntegerValueField(.eventSourceUserData, value: InputWatcher.ownEventTag)
      event?.post(tap: .cghidEventTap)
    }
  }
}

final class SpaceSwitcher {
  static let leftID = 79
  static let rightID = 81
  static let firstDesktopID = 118
  static let numberedDesktops = 9
  private static let timeout: TimeInterval = 3
  private static let pollInterval: TimeInterval = 0.05
  private static let standard: [Int: SpaceKey] = [
    leftID: SpaceKey(keyCode: 123, flags: [.maskControl, .maskSecondaryFn]),
    rightID: SpaceKey(keyCode: 124, flags: [.maskControl, .maskSecondaryFn])
  ]

  func go(to space: UInt64, then done: @escaping (Bool) -> Void) {
    let displays = Spaces.displays()
    let layout = displays.map { "\($0.identifier): \($0.spaces.map(\.id)) current \($0.current)" }.joined(separator: "; ")
    Log.switcher.debug("displays \(layout, privacy: .public)")
    guard let display = displays.first(where: { $0.spaces.contains { $0.id == space } }),
          let target = display.spaces.firstIndex(where: { $0.id == space }),
          let current = display.spaces.firstIndex(where: { $0.id == display.current }) else {
      Log.switcher.debug("Space \(space, privacy: .public) not found")
      return done(false)
    }
    Log.switcher.debug("from index \(current, privacy: .public) to \(target, privacy: .public)")
    guard target != current else { return done(true) }
    let desktops = displays.flatMap { $0.spaces.filter(\.isDesktop) }
    if let number = desktops.firstIndex(where: { $0.id == space }), number < Self.numberedDesktops,
       let key = Self.shortcut(Self.firstDesktopID + number) {
      Log.switcher.debug("press Desktop \(number + 1, privacy: .public) shortcut")
      press(key, times: 1, on: display.identifier, then: done)
      return
    }
    guard isUnderMouse(display) else {
      Log.switcher.debug("stop: Space is on another display than the mouse")
      return done(false)
    }
    guard let key = Self.shortcut(target > current ? Self.rightID : Self.leftID) else {
      Log.switcher.debug("stop: move left/right shortcut is off")
      return done(false)
    }
    Log.switcher.debug("press arrow \(abs(target - current), privacy: .public) times")
    press(key, times: abs(target - current), on: display.identifier, then: done)
  }

  private func isUnderMouse(_ display: DisplaySpaces) -> Bool {
    if display.identifier == "Main" { return true }
    return Spaces.mouseDisplayIdentifier()?.caseInsensitiveCompare(display.identifier) == .orderedSame
  }

  private func press(_ key: SpaceKey, times: Int, on display: String, then done: @escaping (Bool) -> Void) {
    guard times > 0 else { return done(true) }
    let before = currentSpace(on: display)
    let start = Date()
    key.post()
    waitForSpaceChange(on: display, from: before, until: start.addingTimeInterval(Self.timeout)) { [weak self] changed in
      let elapsed = Date().timeIntervalSince(start)
      Log.switcher.debug("Space changed \(changed, privacy: .public) after \(elapsed, privacy: .public)s")
      guard changed else { return done(false) }
      self?.press(key, times: times - 1, on: display, then: done)
    }
  }

  private func waitForSpaceChange(on display: String, from before: UInt64?, until deadline: Date, then action: @escaping (Bool) -> Void) {
    if currentSpace(on: display) != before { return action(true) }
    guard Date() < deadline else { return action(false) }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.pollInterval) { [weak self] in
      guard let self else { return }
      self.waitForSpaceChange(on: display, from: before, until: deadline, then: action)
    }
  }

  private func currentSpace(on display: String) -> UInt64? {
    Spaces.displays().first { $0.identifier == display }?.current
  }

  static func shortcut(_ id: Int) -> SpaceKey? {
    let all = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
    guard let entry = all?[String(id)] as? [String: Any] else { return standard[id] }
    guard (entry["enabled"] as? NSNumber)?.boolValue == true,
          let value = entry["value"] as? [String: Any],
          let parameters = value["parameters"] as? [NSNumber], parameters.count == 3 else { return nil }
    return SpaceKey(
      keyCode: CGKeyCode(parameters[1].intValue),
      flags: CGEventFlags(rawValue: parameters[2].uint64Value)
    )
  }
}
