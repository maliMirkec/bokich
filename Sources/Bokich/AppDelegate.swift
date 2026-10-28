import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusMenu: StatusMenu?
  private let permissions = Permissions()
  private let input = InputWatcher()
  private lazy var follower = SpaceFollower(input: input)
  private lazy var buddy = BuddyWindow()
  private let shortcuts = ShortcutController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusMenu = StatusMenu(buddy: buddy, shortcuts: shortcuts)
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
  }
}
