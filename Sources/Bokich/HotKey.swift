import Carbon

final class HotKey {
  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?
  private let action: () -> Void

  init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
    self.action = action
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let refcon = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(GetApplicationEventTarget(), { _, _, refcon in
      guard let refcon else { return noErr }
      Unmanaged<HotKey>.fromOpaque(refcon).takeUnretainedValue().action()
      return noErr
    }, 1, &spec, refcon, &handlerRef)
    let id = EventHotKeyID(signature: OSType(0x424F4B49), id: 1)
    RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
  }

  deinit {
    if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    if let handlerRef { RemoveEventHandler(handlerRef) }
  }
}
