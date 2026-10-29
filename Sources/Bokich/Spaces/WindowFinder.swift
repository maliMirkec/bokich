import AppKit

struct WindowTarget {
  let pid: pid_t
  let windowID: CGWindowID
  let bounds: CGRect
}

struct NextFocus {
  let target: WindowTarget?
  let display: CGDirectDisplayID?
}

enum WindowFinder {
  private static let minSize: CGFloat = 50

  static func onScreen() -> [WindowTarget] {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
    let ownPID = getpid()
    return list.compactMap { info in
      guard let owner = info[kCGWindowOwnerPID as String] as? pid_t, owner != ownPID,
            let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
            let windowID = info[kCGWindowNumber as String] as? CGWindowID,
            let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsInfo) else { return nil }
      let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
      guard alpha > 0 else { return nil }
      return WindowTarget(pid: owner, windowID: windowID, bounds: bounds)
    }
  }

  static func next(
    excluding pid: pid_t,
    in windows: [WindowTarget] = WindowFinder.onScreen(),
    fallback: CGDirectDisplayID? = nil
  ) -> NextFocus {
    let quittingDisplay = windows.first { $0.pid == pid }.flatMap { display(for: $0.bounds) } ?? fallback
    let candidates = windows.filter {
      $0.pid != pid && $0.bounds.width > minSize && $0.bounds.height > minSize &&
        NSRunningApplication(processIdentifier: $0.pid)?.activationPolicy == .regular
    }
    if let quittingDisplay, let match = candidates.first(where: { display(for: $0.bounds) == quittingDisplay }) {
      return NextFocus(target: match, display: quittingDisplay)
    }
    return NextFocus(target: candidates.first, display: quittingDisplay)
  }

  static func offScreen(of pid: pid_t, preferring preferred: CGWindowID? = nil) -> (window: WindowTarget, space: UInt64)? {
    let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
    guard var list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
    let minimized = WindowFocuser.minimizedWindowIDs(pid)
    for id in [preferred, WindowFocuser.lastUsedWindowID(pid)].compactMap({ $0 }) {
      guard let index = list.firstIndex(where: { $0[kCGWindowNumber as String] as? CGWindowID == id }) else { continue }
      list.insert(list.remove(at: index), at: 0)
    }
    for info in list {
      guard info[kCGWindowOwnerPID as String] as? pid_t == pid,
            info[kCGWindowLayer as String] as? Int == 0,
            info[kCGWindowIsOnscreen as String] as? Bool != true,
            let windowID = info[kCGWindowNumber as String] as? CGWindowID,
            !minimized.contains(windowID),
            let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsInfo),
            bounds.width > minSize, bounds.height > minSize,
            let space = Spaces.spaces(for: windowID).first else { continue }
      return (WindowTarget(pid: pid, windowID: windowID, bounds: bounds), space)
    }
    return nil
  }

  static func topWindow(of pid: pid_t, in windows: [WindowTarget] = WindowFinder.onScreen()) -> CGWindowID? {
    windows.first { $0.pid == pid && $0.bounds.width > minSize && $0.bounds.height > minSize }?.windowID
  }

  static func hasVisibleWindow(_ pid: pid_t, in windows: [WindowTarget] = WindowFinder.onScreen()) -> Bool {
    windows.contains { $0.pid == pid && $0.bounds.width > minSize && $0.bounds.height > minSize }
  }

  static func isPanel(_ id: CGWindowID) -> Bool {
    guard let info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]])?.first,
          info[kCGWindowIsOnscreen as String] as? Bool == true,
          let layer = info[kCGWindowLayer as String] as? Int, layer > 0,
          let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
          let bounds = CGRect(dictionaryRepresentation: boundsInfo) else { return false }
    return bounds.width > minSize && bounds.height > minSize
  }

  static func windows(
    onDisplay id: CGDirectDisplayID?,
    in windows: [WindowTarget] = WindowFinder.onScreen(),
    includeAgents: Bool = false
  ) -> [WindowTarget] {
    windows.filter {
      $0.bounds.width > minSize && $0.bounds.height > minSize && (id == nil || display(for: $0.bounds) == id) &&
        (includeAgents || NSRunningApplication(processIdentifier: $0.pid)?.activationPolicy == .regular)
    }
  }

  static func hit(_ click: Click) -> (pid: pid_t, layer: Int)? {
    var info: [String: Any]?
    if click.windowID != 0 {
      info = (CGWindowListCopyWindowInfo(.optionIncludingWindow, click.windowID) as? [[String: Any]])?.first
    }
    if info == nil {
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
      info = list.first { entry in
        guard let boundsInfo = entry[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsInfo) else { return false }
        return bounds.contains(click.location)
      }
    }
    guard let info, let pid = info[kCGWindowOwnerPID as String] as? pid_t else { return nil }
    return (pid, info[kCGWindowLayer as String] as? Int ?? 0)
  }

  private static func display(for rect: CGRect) -> CGDirectDisplayID? {
    var id: CGDirectDisplayID = 0
    var count: UInt32 = 0
    let center = CGPoint(x: rect.midX, y: rect.midY)
    guard CGGetDisplaysWithPoint(center, 1, &id, &count) == .success, count > 0 else { return nil }
    return id
  }
}
