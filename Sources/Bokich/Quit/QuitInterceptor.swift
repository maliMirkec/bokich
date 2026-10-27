import AppKit

final class QuitInterceptor {
  private static let qKeyCode: Int64 = 12
  private static let finderID = "com.apple.finder"

  private var tap: CFMachPort?
  private var source: CFRunLoopSource?
  var isEnabled: () -> Bool = { true }
  var onQuit: ((NSRunningApplication) -> Void)?

  func start() {
    guard tap == nil else { return }
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    let refcon = Unmanaged.passUnretained(self).toOpaque()
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: quitTapCallback,
      userInfo: refcon
    ) else { return }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    self.tap = tap
    self.source = source
  }

  fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return pass
    }
    guard type == .keyDown, isEnabled() else { return pass }
    guard event.getIntegerValueField(.keyboardEventKeycode) == Self.qKeyCode else { return pass }
    let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    guard modifiers == .maskCommand else { return pass }
    if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
    guard let app = NSWorkspace.shared.frontmostApplication,
          app.bundleIdentifier != Self.finderID,
          app.processIdentifier != getpid() else { return pass }
    DispatchQueue.main.async { [weak self] in
      self?.onQuit?(app)
    }
    return nil
  }
}

private func quitTapCallback(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let refcon else { return Unmanaged.passUnretained(event) }
  let interceptor = Unmanaged<QuitInterceptor>.fromOpaque(refcon).takeUnretainedValue()
  return interceptor.handle(type: type, event: event)
}
