import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusMenu: StatusMenu?
  private let permissions = Permissions()
  private let interceptor = QuitInterceptor()
  private lazy var buddy = BuddyWindow()
  private let anchor = SpaceAnchor()
  private let shortcuts = ShortcutController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusMenu = StatusMenu(buddy: buddy, shortcuts: shortcuts)
    shortcuts.action = { [weak self] in self?.statusMenu?.toggleEnabled() }
    shortcuts.apply()
    if Settings.showBuddy {
      buddy.show()
    }
    interceptor.isEnabled = { Settings.enabled }
    interceptor.onQuit = { [weak self] app in self?.quit(app) }
    permissions.onChange = { [weak self] trusted in
      guard let self else { return }
      self.interceptor.stop()
      if trusted { self.interceptor.start() }
      self.statusMenu?.refresh()
    }
    permissions.start()
  }

  private func quit(_ app: NSRunningApplication) {
    guard FullScreen.exitIfNeeded(app.processIdentifier) else {
      finishQuit(app)
      return
    }
    waitForSpaceChange { [weak self] in
      self?.finishQuit(app)
    }
  }

  private func waitForSpaceChange(then action: @escaping () -> Void) {
    let center = NSWorkspace.shared.notificationCenter
    var token: NSObjectProtocol?
    var done = false
    let finish = {
      guard !done else { return }
      done = true
      if let token { center.removeObserver(token) }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: action)
    }
    token = center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
      finish()
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: finish)
  }

  private func finishQuit(_ app: NSRunningApplication) {
    let expected: pid_t
    let next = WindowFinder.next(excluding: app.processIdentifier)
    if let target = next.target {
      WindowFocuser.focus(target)
      expected = target.pid
    } else {
      anchor.hold(at: anchorPoint(on: next.display))
      expected = getpid()
    }
    waitUntilFrontmost(expected, attempts: 30) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        app.terminate()
        self.buddy.wink()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          if !app.isTerminated { app.terminate() }
        }
      }
    }
  }

  private func anchorPoint(on display: CGDirectDisplayID?) -> NSPoint {
    let mouse = NSEvent.mouseLocation
    let byDisplay = display.flatMap { id in NSScreen.screens.first { $0.displayID == Int(id) } }
    let screen = byDisplay ?? NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
    guard let screen else { return NSPoint(x: buddy.frame.midX, y: buddy.frame.midY) }
    return NSPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY)
  }

  private func waitUntilFrontmost(_ pid: pid_t, attempts: Int, then action: @escaping () -> Void) {
    if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid || attempts == 0 {
      action()
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
      self?.waitUntilFrontmost(pid, attempts: attempts - 1, then: action)
    }
  }
}
