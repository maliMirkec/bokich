import AppKit
import ApplicationServices

final class Permissions {
  private static let waitingInterval: TimeInterval = 2
  private static let trustedInterval: TimeInterval = 30
  private static let notificationDelay: TimeInterval = 0.5

  private var timer: Timer?
  private var observer: NSObjectProtocol?
  private var trusted = false
  var onChange: ((Bool) -> Void)?

  static var isTrusted: Bool {
    AXIsProcessTrusted()
  }

  func start() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    trusted = AXIsProcessTrustedWithOptions(options)
    onChange?(trusted)
    observer = DistributedNotificationCenter.default().addObserver(
      forName: NSNotification.Name("com.apple.accessibility.api"),
      object: nil,
      queue: .main
    ) { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.notificationDelay) {
        self?.check()
      }
    }
    schedule()
  }

  private func schedule() {
    timer?.invalidate()
    let interval = trusted ? Self.trustedInterval : Self.waitingInterval
    let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      self?.check()
    }
    timer.tolerance = interval * 0.2
    self.timer = timer
  }

  private func check() {
    let now = Permissions.isTrusted
    guard now != trusted else { return }
    trusted = now
    schedule()
    onChange?(now)
  }
}
