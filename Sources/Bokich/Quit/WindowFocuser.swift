import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

enum WindowFocuser {
  @discardableResult
  static func focus(_ target: WindowTarget) -> Bool {
    let app = AXUIElementCreateApplication(target.pid)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return false }
    for window in windows {
      var id: CGWindowID = 0
      guard _AXUIElementGetWindow(window, &id) == .success, id == target.windowID else { continue }
      AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
      AXUIElementPerformAction(window, kAXRaiseAction as CFString)
      AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
      return true
    }
    return false
  }

  static func focusApp(_ pid: pid_t) {
    DispatchQueue.global(qos: .userInteractive).async {
      let app = AXUIElementCreateApplication(pid)
      AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    }
  }
}
