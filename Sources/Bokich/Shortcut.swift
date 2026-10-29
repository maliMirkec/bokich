import AppKit
import Carbon

struct Shortcut: Codable, Equatable {
  var keyCode: Int
  var modifiers: UInt
  var key: String

  static let standard = Shortcut(
    keyCode: kVK_ANSI_0,
    modifiers: NSEvent.ModifierFlags([.control, .option, .command]).rawValue,
    key: "0"
  )

  var flags: NSEvent.ModifierFlags {
    NSEvent.ModifierFlags(rawValue: modifiers).intersection([.control, .option, .shift, .command])
  }

  var carbonModifiers: Int {
    var result = 0
    if flags.contains(.control) { result |= controlKey }
    if flags.contains(.option) { result |= optionKey }
    if flags.contains(.shift) { result |= shiftKey }
    if flags.contains(.command) { result |= cmdKey }
    return result
  }

  var display: String {
    var text = ""
    if flags.contains(.control) { text += "⌃" }
    if flags.contains(.option) { text += "⌥" }
    if flags.contains(.shift) { text += "⇧" }
    if flags.contains(.command) { text += "⌘" }
    return text + keyName
  }

  var keyName: String {
    switch keyCode {
    case kVK_Space: return "Space"
    case kVK_Return: return "↩"
    case kVK_Tab: return "⇥"
    case kVK_Delete: return "⌫"
    case kVK_ForwardDelete: return "⌦"
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_UpArrow: return "↑"
    case kVK_DownArrow: return "↓"
    case kVK_Home: return "↖"
    case kVK_End: return "↘"
    case kVK_PageUp: return "⇞"
    case kVK_PageDown: return "⇟"
    default: break
    }
    let functionKeys = [
      kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
      kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
    ]
    if let index = functionKeys.firstIndex(of: keyCode) {
      return "F\(index + 1)"
    }
    return key.uppercased()
  }

  var isValid: Bool {
    flags.contains(.control) || flags.contains(.option)
  }

  var isSpaceShortcut: Bool {
    let mask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    let ownFlags = CGEventFlags(rawValue: UInt64(flags.rawValue)).intersection(mask)
    let desktops = (0..<SpaceSwitcher.numberedDesktops).map { SpaceSwitcher.firstDesktopID + $0 }
    return ([SpaceSwitcher.leftID, SpaceSwitcher.rightID] + desktops).contains { id in
      guard let key = SpaceSwitcher.shortcut(id) else { return false }
      return Int(key.keyCode) == keyCode && key.flags.intersection(mask) == ownFlags
    }
  }

  init(keyCode: Int, modifiers: UInt, key: String) {
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.key = key
  }

  init?(event: NSEvent) {
    guard let key = event.characters(byApplyingModifiers: []), !key.isEmpty else { return nil }
    self.init(keyCode: Int(event.keyCode), modifiers: event.modifierFlags.intersection([.control, .option, .shift, .command]).rawValue, key: key)
  }
}

final class ShortcutController {
  private var hotKey: HotKey?
  var action: () -> Void = {}

  @discardableResult
  func apply() -> Bool {
    hotKey = nil
    if let saved = Settings.shortcut, saved.isSpaceShortcut, saved != .standard {
      Settings.shortcut = .standard
    }
    guard let shortcut = Settings.shortcut else { return true }
    hotKey = HotKey(keyCode: shortcut.keyCode, modifiers: shortcut.carbonModifiers, action: action)
    return hotKey != nil
  }

  func suspend() {
    hotKey = nil
  }
}
