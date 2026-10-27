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

  static func next(excluding pid: pid_t) -> NextFocus {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
      return NextFocus(target: nil, display: nil)
    }
    let ownPID = getpid()
    var quittingBounds: CGRect?
    var candidates: [WindowTarget] = []

    for info in list {
      guard let owner = info[kCGWindowOwnerPID as String] as? pid_t,
            let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
            let windowID = info[kCGWindowNumber as String] as? CGWindowID,
            let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsInfo) else { continue }
      if owner == pid {
        if quittingBounds == nil { quittingBounds = bounds }
        continue
      }
      guard owner != ownPID else { continue }
      let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
      guard alpha > 0, bounds.width > minSize, bounds.height > minSize else { continue }
      guard NSRunningApplication(processIdentifier: owner)?.activationPolicy == .regular else { continue }
      candidates.append(WindowTarget(pid: owner, windowID: windowID, bounds: bounds))
    }

    let quittingDisplay = quittingBounds.flatMap { display(for: $0) }
    if let quittingDisplay, let match = candidates.first(where: { self.display(for: $0.bounds) == quittingDisplay }) {
      return NextFocus(target: match, display: quittingDisplay)
    }
    return NextFocus(target: candidates.first, display: quittingDisplay)
  }

  private static func display(for rect: CGRect) -> CGDirectDisplayID? {
    var id: CGDirectDisplayID = 0
    var count: UInt32 = 0
    let center = CGPoint(x: rect.midX, y: rect.midY)
    guard CGGetDisplaysWithPoint(center, 1, &id, &count) == .success, count > 0 else { return nil }
    return id
  }
}
