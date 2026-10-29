import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusMenu: StatusMenu?
  private let permissions = Permissions()
  private let input = InputWatcher()
  private lazy var follower = SpaceFollower(input: input)
  private lazy var buddy = BuddyWindow()
  private let shortcuts = ShortcutController()
  private var windowObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusMenu = StatusMenu(buddy: buddy, shortcuts: shortcuts)
    statusMenu?.onToggle = { [weak self] enabled in
      if !enabled { self?.follower.release() }
    }
    shortcuts.action = { [weak self] in self?.statusMenu?.toggleEnabled() }
    shortcuts.apply()
    if Settings.showBuddy {
      buddy.show()
    }
    follower.isEnabled = { Settings.enabled && Permissions.isTrusted }
    follower.onFollow = { [weak self] in self?.buddy.wink() }
    follower.onTakeOver = { [weak self] in self?.buddy.greet() }
    permissions.onChange = { [weak self] trusted in
      guard let self else { return }
      self.input.stop()
      if trusted { self.input.start() }
      self.statusMenu?.refresh()
    }
    permissions.start()
    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification,
      object: nil,
      queue: .main
    ) { [weak self] note in
      self?.windowClosed(note.object as? NSWindow)
    }
  }

  private func windowClosed(_ window: NSWindow?) {
    DispatchQueue.main.async { [weak self] in
      let open = NSApp.windows.contains { $0 !== window && $0.isVisible && $0.styleMask.contains(.titled) }
      guard NSApp.isActive, !open else { return }
      self?.follower.giveBackFocus()
    }
  }
}
