import AppKit
import ApplicationServices

enum FullScreen {
  private static let attribute = "AXFullScreen" as CFString

  static func exitIfNeeded(_ pid: pid_t) -> Bool {
    let app = AXUIElementCreateApplication(pid)
    var windowValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
          let windowValue,
          CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { return false }
    let window = windowValue as! AXUIElement
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, attribute, &value) == .success,
          (value as? Bool) == true else { return false }
    return AXUIElementSetAttributeValue(window, attribute, kCFBooleanFalse) == .success
  }
}
