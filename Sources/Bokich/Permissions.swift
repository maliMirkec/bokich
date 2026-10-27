import AppKit
import ApplicationServices

final class Permissions {
  private var timer: Timer?
  var onTrusted: (() -> Void)?

  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  func start() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    if AXIsProcessTrustedWithOptions(options) {
      onTrusted?()
      return
    }
    timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
      guard let self, Permissions.isTrusted else { return }
      timer.invalidate()
      self.timer = nil
      self.onTrusted?()
    }
  }

  static func openSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
    NSWorkspace.shared.open(url)
  }
}
