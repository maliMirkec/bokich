import AppKit

final class QuitInterceptor {
  private static let qKeyCode: Int64 = 12
  private static let wKeyCode: Int64 = 13
  private static let finderID = "com.apple.finder"

  private var tap: CFMachPort?
  private var source: CFRunLoopSource?
  private var runLoop: CFRunLoop?
  var isEnabled: () -> Bool = { true }
  var onQuit: ((NSRunningApplication) -> Void)?
  let closeQuitters = CloseQuitters()

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
    guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return }
    self.tap = tap
    self.source = source
    let ready = DispatchSemaphore(value: 0)
    let thread = Thread { [weak self] in
      let loop = CFRunLoopGetCurrent()
      self?.runLoop = loop
      CFRunLoopAddSource(loop, source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
      ready.signal()
      CFRunLoopRun()
    }
    thread.name = "Bokich.QuitTap"
    thread.qualityOfService = .userInteractive
    thread.start()
    ready.wait()
  }

  func stop() {
    if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let runLoop, let source {
      CFRunLoopRemoveSource(runLoop, source, .commonModes)
      CFRunLoopStop(runLoop)
    }
    if let tap { CFMachPortInvalidate(tap) }
    tap = nil
    source = nil
    runLoop = nil
  }

  fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return pass
    }
    guard type == .keyDown, isEnabled() else { return pass }
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keyCode == Self.qKeyCode || keyCode == Self.wKeyCode else { return pass }
    let modifiers = event.flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    guard modifiers == .maskCommand else { return pass }
    guard let app = NSWorkspace.shared.frontmostApplication,
          app.bundleIdentifier != Self.finderID,
          app.processIdentifier != getpid() else { return pass }
    if keyCode == Self.wKeyCode {
      guard closeQuitters.contains(app), CloseQuitters.windowCount(app.processIdentifier) == 1 else {
        closeQuitters.noteClose(app)
        return pass
      }
    }
    if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return nil }
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
