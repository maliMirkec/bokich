import AppKit

final class SpaceFollower {
  private static let inputWindow: TimeInterval = 1
  private static let switchKeyWindow: TimeInterval = 2.5
  private static let leaveWindow: TimeInterval = 2
  private static let settleDelay: TimeInterval = 0.5
  private static let leaveDelay: TimeInterval = 0.15
  private static let focusDelay: TimeInterval = 0.2
  private static let spaceDelay: TimeInterval = 0.3
  private static let switchHold: TimeInterval = 0.6
  private static let holdGrace: TimeInterval = 0.5
  private static let greetCooldown: TimeInterval = 5
  private static let windowManagerID = "com.apple.WindowManager"
  private static let promptIDs: Set<String> = ["com.apple.SecurityAgent", "com.apple.LocalAuthentication.UIAgent"]

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
  private var switchEnded: Date?
  private var pendingFollow: pid_t?
  private var holdStart: (pid: pid_t?, time: Date)?
  private var spaceChanges = 0
  private var currentSpaces = SpaceFollower.spacesByDisplay()
  private var changedDisplays: Set<String> = []
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
    if pid != getpid(), anchor.isHolding, !isLateActivation(pid) {
      Log.follow.debug("\(Log.name(pid), privacy: .public) is front: Bokich lets the Space go")
      anchor.release()
    }
    let leftName = left.map { Log.name($0.processIdentifier) } ?? "none"
    Log.follow.debug("activated \(Log.name(pid), privacy: .public), left \(leftName, privacy: .public)")
    guard isEnabled(), pid != getpid() else { return }
    if isPrompt(app) {
      Log.follow.debug("skip: prompt")
      return
    }
    if isIgnored(pid) {
      Log.follow.debug("skip: Bokich caused it")
      return
    }
    if leftByShortcut(at: time) {
      Log.follow.debug("take over: Cmd+Q, Cmd+W, Cmd+H, or Cmd+M")
      takeOver(excluding: left?.processIdentifier)
      return
    }
    let caused = causedByUser(pid, at: time)
    if caused {
      pendingFollow = pid
    } else {
      Log.follow.debug("no recent key or click yet: check again")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [weak self] in
      guard let self else { return }
      if self.pendingFollow == pid { self.pendingFollow = nil }
      guard self.isEnabled() else { return }
      guard caused || self.causedByUser(pid, at: time) else {
        Log.follow.debug("skip: no recent key or click")
        return
      }
      guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
        Log.follow.debug("skip: \(Log.name(pid), privacy: .public) no longer front")
        return
      }
      if let left, left.isTerminated || left.isHidden, !self.isPrompt(left) {
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

  private func leftByShortcut(at time: Date) -> Bool {
    guard let key = input.lastKeyPress, key.isLeaveShortcut, time.timeIntervalSince(key.time) < Self.leaveWindow,
          input.isLastKeyDown(key) else { return false }
    if let click = input.lastClick, click.time > key.time { return false }
    return true
  }

  private func causedByUser(_ pid: pid_t, at time: Date) -> Bool {
    if input.isSwitchKey(near: time, within: Self.switchKeyWindow) {
      Log.input.debug("switch key near activation")
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
    guard !isSwitching else {
      Log.follow.debug("skip: another switch is running")
      return
    }
    let dialog = isDialog(NSRunningApplication(processIdentifier: pid))
    if let window = WindowFinder.visibleWindow(of: pid, preferring: lastWindows[pid]) {
      Log.follow.debug("no switch: \(Log.name(pid), privacy: .public) has window \(window.windowID, privacy: .public) on screen, dialog \(dialog, privacy: .public)")
      if !dialog {
        let raised = WindowFocuser.focus(window)
        Log.follow.debug("raised window: \(raised, privacy: .public)")
      }
      return
    }
    if dialog {
      Log.follow.debug("skip: dialog is front")
      return
    }
    guard let found = WindowFinder.offScreen(of: pid, preferring: lastWindows[pid]) else {
      Log.follow.debug("skip: no window with a Space found for \(Log.name(pid), privacy: .public)")
      return
    }
    Log.follow.debug("follow \(Log.name(pid), privacy: .public) to window \(found.window.windowID, privacy: .public) on Space \(found.space, privacy: .public)")
    isSwitching = true
    let changesBefore = spaceChanges
    switcher.go(to: found.space) { [weak self] arrived in
      guard let self else { return }
      Log.follow.debug("arrived: \(arrived, privacy: .public)")
      self.isSwitching = false
      if arrived || self.spaceChanges != changesBefore { self.switchEnded = Date() }
      guard arrived else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.focusDelay) { [weak self] in
        guard let self, self.isEnabled() else { return }
        self.ignore(pid)
        WindowFocuser.focus(found.window)
        self.onFollow?()
      }
    }
  }

  private func left(_ app: NSRunningApplication) {
    let pid = app.processIdentifier
    if app.isTerminated { lastWindows[pid] = nil }
    let wasFront = wasFrontmost(pid)
    Log.follow.debug("left \(Log.name(pid), privacy: .public), terminated \(app.isTerminated, privacy: .public), was front \(wasFront, privacy: .public)")
    guard wasFront, pid != getpid() else { return }
    if isPrompt(app) {
      Log.follow.debug("skip: prompt closed")
      return
    }
    lastLeave = Date()
    guard isEnabled() else { return }
    if let pendingFollow, pendingFollow != pid {
      Log.follow.debug("skip: a switch to \(Log.name(pendingFollow), privacy: .public) decides")
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.leaveDelay) { [weak self] in
      guard let self, self.isEnabled() else { return }
      self.takeOver(excluding: pid)
    }
  }

  private func takeOver(excluding pid: pid_t?) {
    guard !anchor.isHolding else { return }
    let all = WindowFinder.onScreen()
    let visible = all.filter { $0.pid != pid }
    if let front = NSWorkspace.shared.frontmostApplication?.processIdentifier,
       front != pid, WindowFinder.hasVisibleWindow(front, in: visible) {
      Log.follow.debug("take over: \(Log.name(front), privacy: .public) already has a window here")
      return
    }
    if isDialog(NSWorkspace.shared.frontmostApplication) {
      Log.follow.debug("take over: skip, dialog is front")
      return
    }
    if let target = WindowFinder.next(excluding: pid ?? 0, in: all, fallback: mouseDisplay()).target {
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
    let spaces = Self.spacesByDisplay()
    changedDisplays.formUnion(spaces.filter { currentSpaces[$0.key] != $0.value }.keys)
    currentSpaces = spaces
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.spaceDelay) { [weak self] in
      guard let self, change == self.spaceChanges else { return }
      let changed = self.changedDisplays
      self.changedDisplays = []
      guard !self.isSwitching, !self.recentlySwitched, self.isEnabled() else { return }
      self.landed(on: self.changedScreen(changed))
    }
  }

  private static func spacesByDisplay() -> [String: UInt64] {
    Dictionary(Spaces.displays().map { ($0.identifier, $0.current) }, uniquingKeysWith: { first, _ in first })
  }

  private func changedScreen(_ changed: Set<String>) -> NSScreen? {
    let mouse = mouseScreen()
    guard NSScreen.screensHaveSeparateSpaces else { return mouse }
    let screens = changed.compactMap { Spaces.screen(for: $0) }
    if let mouse, screens.contains(where: { $0.displayID == mouse.displayID }) { return mouse }
    return screens.first ?? mouse
  }

  private func landed(on screen: NSScreen?) {
    guard let screen, let id = screen.displayID else { return }
    let display: CGDirectDisplayID? = NSScreen.screensHaveSeparateSpaces ? CGDirectDisplayID(id) : nil
    let here = WindowFinder.windows(onDisplay: display)
    if here.isEmpty {
      let front = NSWorkspace.shared.frontmostApplication
      if let front, front.processIdentifier != getpid(),
         WindowFinder.windows(onDisplay: display, includeAgents: true).contains(where: { $0.pid == front.processIdentifier }) {
        Log.follow.debug("landed: skip, \(Log.name(front.processIdentifier), privacy: .public) has a window here")
        return
      }
      if isDialog(front) {
        Log.follow.debug("landed on an empty Space: skip, dialog is front")
        return
      }
      Log.follow.debug("landed on an empty Space: Bokich holds it")
      hold(on: screen)
      greet()
    } else if anchor.isHolding, let target = here.first {
      Log.follow.debug("landed on a Space with windows: focus \(Log.name(target.pid), privacy: .public)")
      anchor.release()
      ignore(target.pid)
      WindowFocuser.focus(target)
    }
  }

  private func hold(on screen: NSScreen? = nil) {
    let frame = (screen ?? mouseScreen())?.visibleFrame ?? .zero
    holdStart = (NSWorkspace.shared.frontmostApplication?.processIdentifier, Date())
    anchor.hold(at: NSPoint(x: frame.midX, y: frame.midY))
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.holdGrace) { [weak self] in
      guard let self, self.anchor.isHolding, !NSApp.isActive else { return }
      Log.follow.debug("hold: Bokich is not active, let the Space go")
      self.anchor.release()
    }
  }

  private func isLateActivation(_ pid: pid_t) -> Bool {
    guard let holdStart, holdStart.pid == pid else { return false }
    return Date().timeIntervalSince(holdStart.time) < Self.holdGrace
  }

  private func mouseScreen() -> NSScreen? {
    let mouse = NSEvent.mouseLocation
    return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
  }

  private func mouseDisplay() -> CGDirectDisplayID? {
    mouseScreen()?.displayID.map { CGDirectDisplayID($0) }
  }

  private var recentlySwitched: Bool {
    guard let switchEnded else { return false }
    return Date().timeIntervalSince(switchEnded) < Self.switchHold
  }

  private func greet() {
    if let lastGreet, Date().timeIntervalSince(lastGreet) < Self.greetCooldown { return }
    lastGreet = Date()
    onTakeOver?()
  }

  private func remember(_ app: NSRunningApplication) {
    let pid = app.processIdentifier
    guard pid != getpid() else { return }
    if let id = WindowFinder.topWindow(of: pid) {
      store(id, for: pid)
      return
    }
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let id = WindowFocuser.lastUsedWindowID(pid) else { return }
      DispatchQueue.main.async {
        self?.store(id, for: pid)
      }
    }
  }

  private func store(_ id: CGWindowID, for pid: pid_t) {
    guard NSRunningApplication(processIdentifier: pid)?.isTerminated == false else { return }
    lastWindows[pid] = id
    Log.follow.debug("remember \(Log.name(pid), privacy: .public) window \(id, privacy: .public)")
  }

  func release() {
    guard anchor.isHolding else { return }
    Log.follow.debug("turned off: Bokich lets the Space go")
    anchor.release()
    focusTopWindow()
  }

  func giveBackFocus() {
    guard !anchor.isHolding else { return }
    Log.follow.debug("Bokich window closed: give focus back")
    focusTopWindow()
  }

  private func focusTopWindow() {
    guard let target = WindowFinder.next(excluding: getpid()).target else { return }
    ignore(target.pid)
    WindowFocuser.focus(target)
  }

  private func wasFrontmost(_ pid: pid_t) -> Bool {
    if front?.processIdentifier == pid { return true }
    guard let previous, previous.app.processIdentifier == pid else { return false }
    return Date().timeIntervalSince(previous.time) < Self.inputWindow
  }

  private func isPrompt(_ app: NSRunningApplication) -> Bool {
    guard let id = app.bundleIdentifier else { return false }
    return Self.promptIDs.contains(id)
  }

  private func isDialog(_ app: NSRunningApplication?) -> Bool {
    guard let app, app.processIdentifier != getpid() else { return false }
    if isPrompt(app) { return true }
    guard let window = WindowFocuser.lastUsedWindowID(app.processIdentifier) else { return false }
    return WindowFinder.isPanel(window)
  }

  private func ignore(_ pid: pid_t) {
    ignored = (pid, Date())
  }

  private func isIgnored(_ pid: pid_t) -> Bool {
    guard let ignored, ignored.pid == pid else { return false }
    return Date().timeIntervalSince(ignored.time) < Self.inputWindow
  }
}
