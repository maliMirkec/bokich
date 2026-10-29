import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

enum WindowFocuser {
  @discardableResult
  static func focus(_ target: WindowTarget) -> Bool {
    let app = AXUIElementCreateApplication(target.pid)
    AXUIElementSetMessagingTimeout(app, 0.5)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return false }
    for window in windows {
      var id: CGWindowID = 0
      guard _AXUIElementGetWindow(window, &id) == .success, id == target.windowID else { continue }
      AXUIElementSetMessagingTimeout(window, 0.5)
      AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
      AXUIElementPerformAction(window, kAXRaiseAction as CFString)
      AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
      return true
    }
    return false
  }

  static func lastUsedWindowID(_ pid: pid_t) -> CGWindowID? {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.2)
    for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
      var value: CFTypeRef?
      guard AXUIElementCopyAttributeValue(app, attribute as CFString, &value) == .success,
            let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { continue }
      var id: CGWindowID = 0
      if _AXUIElementGetWindow(value as! AXUIElement, &id) == .success, id != 0 { return id }
    }
    return nil
  }

  static func minimizedWindowIDs(_ pid: pid_t) -> Set<CGWindowID> {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.2)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return [] }
    var result: Set<CGWindowID> = []
    for window in windows {
      var minimized: CFTypeRef?
      var id: CGWindowID = 0
      guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
            (minimized as? Bool) == true,
            _AXUIElementGetWindow(window, &id) == .success else { continue }
      result.insert(id)
    }
    return result
  }

  static func focusApp(_ pid: pid_t) {
    DispatchQueue.global(qos: .userInteractive).async {
      let app = AXUIElementCreateApplication(pid)
      AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }
  }
}
