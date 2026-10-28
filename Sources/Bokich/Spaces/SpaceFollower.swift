import AppKit

final class SpaceFollower {
  private static let inputWindow: TimeInterval = 1
  private static let leaveWindow: TimeInterval = 2
  private static let settleDelay: TimeInterval = 0.5
  private static let leaveDelay: TimeInterval = 0.15
  private static let focusDelay: TimeInterval = 0.2
  private static let spaceDelay: TimeInterval = 0.3
  private static let greetCooldown: TimeInterval = 5
  private static let windowManagerID = "com.apple.WindowManager"

  var isEnabled: () -> Bool = { true }
  var onFollow: (() -> Void)?
  var onTakeOver: (() -> Void)?
  private let input: InputWatcher
  private let switcher = SpaceSwitcher()
  private let anchor = SpaceAnchor()
  private var front = NSWorkspace.shared.frontmostApplication
  private var previous: (app: NSRunningApplication, time: Date)?
  private var lastLeave: Date?
  private var ignored: (pid: pid_t, time: Date)?
  private var isSwitching = false
  private var spaceChanges = 0
  private var lastGreet: Date?
  private var lastWindows: [pid_t: CGWindowID] = [:]
  private var observers: [NSObjectProtocol] = []

  init(input: InputWatcher) {
    self.input = input
    observe(NSWorkspace.didActivateApplicationNotification) { [weak self] app in
      self?.activated(app)
    }
    observe(NSWorkspace.didTerminateApplicationNotification) { [weak self] app in
      self?.left(app)
    }
    observe(NSWorkspace.didHideApplicationNotification) { [weak self] app in
      self?.left(app)
    }
    let center = NSWorkspace.shared.notificationCenter
    observers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
      self?.spaceChanged()
    })
  }

  private func observe(_ name: Notification.Name, _ handler: @escaping (NSRunningApplication) -> Void) {
    let center = NSWorkspace.shared.notificationCenter
    observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
      if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
        handler(app)
      }
    })
  }

  private func activated(_ app: NSRunningApplication) {
    let pid = app.processIdentifier
    let time = Date()
    let left = front
    if let front, front.processIdentifier != pid {
      previous = (front, time)
      remember(front)
    }
    front = app
    let leftName = left.map { Log.name($0.processIdentifier) } ?? "none"
    Log.follow.debug("activated \(Log.name(pid), privacy: .public), left \(leftName, privacy: .public)")
    guard isEnabled(), pid != getpid() else { return }
    if isIgnored(pid) {
      Log.follow.debug("skip: Bokich caused it")
      return
    }
    if let reason = leaving(left, at: time) {
      Log.follow.debug("take over: \(reason, privacy: .public)")
      takeOver(excluding: left?.processIdentifier)
      return
    }
    guard causedByUser(pid, at: time) else {
      Log.follow.debug("skip: no recent key or click")
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
      guard let self else { return }
      guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
        Log.follow.debug("skip: \(Log.name(pid), privacy: .public) no longer front")
        return
      }
      if let left, left.isTerminated || left.isHidden {
        Log.follow.debug("take over: left app quit or hid")
        self.takeOver(excluding: left.processIdentifier)
        return
      }
      if let lastLeave = self.lastLeave, abs(lastLeave.timeIntervalSince(time)) < Self.inputWindow {
        Log.follow.debug("take over: an app quit or hid near this switch")
        self.takeOver(excluding: left?.processIdentifier)
        return
      }
      self.follow(pid)
    }
  }

  private func leaving(_ left: NSRunningApplication?, at time: Date) -> String? {
    if let key = input.lastKeyPress, key.isLeaveShortcut, time.timeIntervalSince(key.time) < Self.leaveWindow,
       input.isLastKeyDown(key) {
      return "Cmd+Q, Cmd+W, Cmd+H, or Cmd+M"
    }
    guard let left, let click = input.lastClick, time.timeIntervalSince(click.time) < Self.inputWindow,
          let hit = WindowFinder.hit(click), hit.pid == left.processIdentifier, hit.layer != 0 else { return nil }
    return "menu click in the app you left"
  }

  private func causedByUser(_ pid: pid_t, at time: Date) -> Bool {
    let keyAge = input.secondsSinceKey - Date().timeIntervalSince(time)
    if keyAge < Self.inputWindow {
      Log.input.debug("key \(keyAge, privacy: .public)s ago")
      return true
    }
    guard let click = input.lastClick, time.timeIntervalSince(click.time) < Self.inputWindow else { return false }
    guard let hit = WindowFinder.hit(click) else { return true }
    let isDesktop = hit.layer < 0 ||
      NSRunningApplication(processIdentifier: hit.pid)?.bundleIdentifier == Self.windowManagerID
    Log.input.debug("click on \(Log.name(hit.pid), privacy: .public) layer \(hit.layer, privacy: .public)")
    return hit.pid != pid && !isDesktop
  }

  private func follow(_ pid: pid_t) {
    if WindowFinder.hasVisibleWindow(pid) {
      Log.follow.debug("skip: \(Log.name(pid), privacy: .public) has a window on screen")
      return
    }
    guard let found = WindowFinder.offScreen(of: pid, preferring: lastWindows[pid]) else {
      Log.follow.debug("skip: no window with a Space found for \(Log.name(pid), privacy: .public)")
      return
    }
    Log.follow.debug("follow \(Log.name(pid), privacy: .public) to window \(found.window.windowID, privacy: .public) on Space \(found.space, privacy: .public)")
    isSwitching = true
    switcher.go(to: found.space) { [weak self] arrived in
      Log.follow.debug("arrived: \(arrived, privacy: .public)")
      self?.isSwitching = false
      guard arrived else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.focusDelay) {
        self?.ignore(pid)
        WindowFocuser.focus(found.window)
        self?.onFollow?()
      }
    }
  }

  private func left(_ app: NSRunningApplication) {
    let pid = app.processIdentifier
    lastLeave = Date()
    if app.isTerminated { lastWindows[pid] = nil }
    let wasFront = wasFrontmost(pid)
    Log.follow.debug("left \(Log.name(pid), privacy: .public), terminated \(app.isTerminated, privacy: .public), was front \(wasFront, privacy: .public)")
    guard isEnabled(), wasFront else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.leaveDelay) { [weak self] in
      self?.takeOver(excluding: pid)
    }
  }

  private func takeOver(excluding pid: pid_t?) {
    guard !anchor.isHolding else { return }
    let visible = WindowFinder.onScreen().filter { $0.pid != pid }
    if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
       front != pid, WindowFinder.hasVisibleWindow(front, in: visible) {
      Log.follow.debug("take over: \(Log.name(front), privacy: .public) already has a window here")
      return
    }
    if let target = WindowFinder.next(excluding: pid ?? 0, in: visible).target {
      Log.follow.debug("take over: focus \(Log.name(target.pid), privacy: .public) window \(target.windowID, privacy: .public)")
      ignore(target.pid)
      WindowFocuser.focus(target)
    } else {
      Log.follow.debug("take over: Bokich holds the Space")
      hold()
    }
    greet()
  }

  private func spaceChanged() {
    spaceChanges += 1
    let change = spaceChanges
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.spaceDelay) { [weak self] in
      guard let self, change == self.spaceChanges, !self.isSwitching, self.isEnabled() else { return }
      self.landed()
    }
  }

  private func landed() {
    guard let id = mouseScreen()?.displayID else { return }
    let here = WindowFinder.windows(onDisplay: CGDirectDisplayID(id))
    if here.isEmpty {
      Log.follow.debug("landed on an empty Space: Bokich holds it")
      hold()
      greet()
    } else if anchor.isHolding, let target = here.first {
      Log.follow.debug("landed on a Space with windows: focus \(Log.name(target.pid), privacy: .public)")
      anchor.release()
      ignore(target.pid)
      WindowFocuser.focus(target)
    }
  }

  private func hold() {
    let frame = mouseScreen()?.visibleFrame ?? .zero
    anchor.hold(at: NSPoint(x: frame.midX, y: frame.midY))
  }

  private func mouseScreen() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
  }

  private func greet() {
    if let lastGreet, Date().timeIntervalSince(lastGreet) < Self.greetCooldown { return }
    lastGreet = Date()
    onTakeOver?()
  }

  private func remember(_ app: NSRunningApplication) {
    let pid = app.processIdentifier
    guard pid != getpid(), let id = WindowFinder.topWindow(of: pid) ?? WindowFocuser.lastUsedWindowID(pid) else { return }
    lastWindows[pid] = id
    Log.follow.debug("remember \(Log.name(pid), privacy: .public) window \(id, privacy: .public)")
  }

  private func wasFrontmost(_ pid: pid_t) -> Bool {
    if front?.processIdentifier == pid { return true }
    guard let previous, previous.app.processIdentifier == pid else { return false }
    return Date().timeIntervalSince(previous.time) < Self.inputWindow
  }

  private func ignore(_ pid: pid_t) {
    ignored = (pid, Date())
  }

  private func isIgnored(_ pid: pid_t) -> Bool {
    guard let ignored, ignored.pid == pid else { return false }
    return Date().timeIntervalSince(ignored.time) < Self.inputWindow
  }
}
