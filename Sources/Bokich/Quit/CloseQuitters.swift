import AppKit
import ApplicationServices

final class CloseQuitters {
  private static let learnWindow: TimeInterval = 1.5

  private var lastClose: (pid: pid_t, time: Date)?
  private var observer: NSObjectProtocol?

  init() {
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didTerminateApplicationNotification,
      object: nil,
      queue: .main
    ) { [weak self] note in
      let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
      if let app { self?.learn(from: app) }
    }
  }

  func contains(_ app: NSRunningApplication) -> Bool {
    guard let id = app.bundleIdentifier else { return false }
    return Settings.closeQuitters.contains(id)
  }

  func noteClose(_ app: NSRunningApplication) {
    let pid = app.processIdentifier
    let time = Date()
    DispatchQueue.main.async { [weak self] in
      self?.lastClose = (pid, time)
    }
  }

  private func learn(from app: NSRunningApplication) {
    guard let lastClose, lastClose.pid == app.processIdentifier,
          Date().timeIntervalSince(lastClose.time) < Self.learnWindow,
          let id = app.bundleIdentifier else { return }
    self.lastClose = nil
    Settings.closeQuitters.insert(id)
  }

  static func windowCount(_ pid: pid_t) -> Int {
    let app = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(app, 0.2)
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
          let windows = value as? [AXUIElement] else { return 0 }
    return windows.count
  }
}
