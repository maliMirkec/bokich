import AppKit
import Carbon

final class ShortcutRecorder: NSObject, NSWindowDelegate {
  private let controller: ShortcutController
  private var panel: NSPanel?
  private var monitor: Any?
  private let keysLabel = NSTextField(labelWithString: "")
  private let hintLabel = NSTextField(labelWithString: "")

  init(controller: ShortcutController) {
    self.controller = controller
    super.init()
  }

  func show() {
    if let panel {
      NSApp.activate(ignoringOtherApps: true)
      panel.makeKeyAndOrderFront(nil)
      return
    }
    controller.suspend()
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 340, height: 170),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    panel.title = "Bokich Shortcut"
    panel.isReleasedWhenClosed = false
    panel.delegate = self
    panel.contentView = makeContent()
    panel.center()
    self.panel = panel
    showCurrent()
    resetHint()
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      self?.record(event)
      return nil
    }
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  private func makeContent() -> NSView {
    let title = NSTextField(labelWithString: "Press a new shortcut to turn Bokich on and off.")
    keysLabel.font = .systemFont(ofSize: 22, weight: .medium)
    keysLabel.alignment = .center
    hintLabel.font = .systemFont(ofSize: 11)
    hintLabel.textColor = .secondaryLabelColor
    hintLabel.alignment = .center
    let reset = NSButton(title: "Use \(Shortcut.standard.display)", target: self, action: #selector(useStandard))
    let off = NSButton(title: "Turn Off", target: self, action: #selector(turnOff))
    let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
    let buttons = NSStackView(views: [reset, off, cancel])
    buttons.spacing = 8
    let stack = NSStackView(views: [title, keysLabel, hintLabel, buttons])
    stack.orientation = .vertical
    stack.spacing = 12
    stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    return stack
  }

  private func showCurrent() {
    keysLabel.stringValue = Settings.shortcut?.display ?? "Off"
  }

  private func resetHint() {
    hintLabel.textColor = .secondaryLabelColor
    hintLabel.stringValue = "Use ⌃ or ⌥ with a key. Esc cancels."
  }

  private func warn(_ text: String) {
    hintLabel.textColor = .systemRed
    hintLabel.stringValue = text
  }

  private func record(_ event: NSEvent) {
    let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
    if Int(event.keyCode) == kVK_Escape && modifiers.isEmpty {
      cancel()
      return
    }
    guard let shortcut = Shortcut(event: event) else { return }
    keysLabel.stringValue = shortcut.display
    guard shortcut.isValid else {
      warn("Add ⌃ or ⌥ to the shortcut.")
      return
    }
    guard !shortcut.isSpaceShortcut else {
      warn("macOS uses that shortcut to switch Spaces.")
      return
    }
    save(shortcut)
  }


  private func save(_ shortcut: Shortcut?) {
    let previous = Settings.shortcut
    Settings.shortcut = shortcut
    guard controller.apply() else {
      Settings.shortcut = previous
      controller.suspend()
      warn("That shortcut is taken. Try another one.")
      return
    }
    close()
  }

  @objc private func useStandard() {
    save(.standard)
  }

  @objc private func turnOff() {
    save(nil)
  }

  @objc private func cancel() {
    controller.apply()
    close()
  }

  private func close() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    let panel = self.panel
    self.panel = nil
    panel?.delegate = nil
    panel?.close()
  }

  func windowWillClose(_ notification: Notification) {
    cancel()
  }
}
