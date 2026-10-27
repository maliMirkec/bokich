import AppKit
import ServiceManagement

final class StatusMenu: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()
  private let buddy: BuddyWindow
  private let recorder: ShortcutRecorder
  private static let website = URL(string: "https://www.silvestar.codes")!

  init(buddy: BuddyWindow, shortcuts: ShortcutController) {
    self.buddy = buddy
    recorder = ShortcutRecorder(controller: shortcuts)
    super.init()
    updateIcon()
    menu.delegate = self
    buildMenu()
    statusItem.menu = menu
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    buildMenu()
  }

  private func buildMenu() {
    menu.removeAllItems()
    let enabled = addItem("Enabled", #selector(toggleEnabled))
    enabled.state = Settings.enabled ? .on : .off
    if let shortcut = Settings.shortcut {
      enabled.keyEquivalent = shortcut.key
      enabled.keyEquivalentModifierMask = shortcut.flags
    }
    addItem("Change Shortcut…", #selector(changeShortcut))
    addItem("Show Bokić", #selector(toggleBuddy)).state = Settings.showBuddy ? .on : .off
    addItem("Reset Bokić Position", #selector(resetPosition))
    addItem("Launch at Login", #selector(toggleLaunchAtLogin)).state = SMAppService.mainApp.status == .enabled ? .on : .off
    if !Permissions.isTrusted {
      addItem("Needs Accessibility Access…", #selector(openAccessibility))
    }
    menu.addItem(.separator())
    addItem("About Bokich", #selector(showAbout))
    addItem("Made by Silvestar Bistrović", #selector(openWebsite))
    menu.addItem(.separator())
    addItem("Quit Bokich", #selector(quitApp))
  }

  @discardableResult
  private func addItem(_ title: String, _ action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    menu.addItem(item)
    return item
  }

  @objc func toggleEnabled() {
    Settings.enabled.toggle()
    updateIcon()
    buddy.setEnabled(Settings.enabled)
  }

  @objc private func changeShortcut() {
    recorder.show()
  }

  @objc private func toggleBuddy() {
    Settings.showBuddy.toggle()
    buddy.setVisible(Settings.showBuddy)
  }

  @objc private func resetPosition() {
    buddy.resetPosition()
    if !Settings.showBuddy {
      Settings.showBuddy = true
      buddy.setVisible(true)
    }
  }

  @objc private func toggleLaunchAtLogin() {
    let service = SMAppService.mainApp
    do {
      if service.status == .enabled {
        try service.unregister()
      } else {
        try service.register()
      }
    } catch {
      let alert = NSAlert()
      alert.messageText = "Could not change Launch at Login"
      alert.informativeText = error.localizedDescription
      NSApp.activate(ignoringOtherApps: true)
      alert.runModal()
    }
  }

  @objc private func openAccessibility() {
    Permissions.openSettings()
  }

  @objc private func showAbout() {
    let credits = NSMutableAttributedString(
      string: "Keeps you on your Space when you quit an app.\n\nMIT License\n",
      attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
    )
    credits.append(NSAttributedString(
      string: "silvestar.codes",
      attributes: [.font: NSFont.systemFont(ofSize: 11), .link: StatusMenu.website]
    ))
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    credits.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: credits.length))
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
  }

  @objc private func openWebsite() {
    NSWorkspace.shared.open(StatusMenu.website)
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  func refresh() {
    updateIcon()
  }

  private func updateIcon() {
    let trusted = Permissions.isTrusted
    statusItem.button?.image = StatusMenu.makeIcon(enabled: Settings.enabled, warning: !trusted)
    statusItem.button?.appearsDisabled = !Settings.enabled
    if !trusted {
      statusItem.button?.toolTip = "Bokich needs Accessibility access"
    } else {
      statusItem.button?.toolTip = Settings.enabled ? "Bokich" : "Bokich (off)"
    }
  }

  static func makeIcon(enabled: Bool, warning: Bool = false) -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size, flipped: false) { rect in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      let outline: [CGPoint] = [
        CGPoint(x: 7.2, y: 16), CGPoint(x: 12.6, y: 15.6), CGPoint(x: 16.2, y: 11.6), CGPoint(x: 15.4, y: 6.2),
        CGPoint(x: 11.8, y: 2.4), CGPoint(x: 6, y: 2.6), CGPoint(x: 2.2, y: 6.4), CGPoint(x: 2.4, y: 11.8)
      ]
      context.setStrokeColor(NSColor.black.cgColor)
      context.setFillColor(NSColor.black.cgColor)
      context.setLineWidth(1.3)
      context.addPath(BlobShape.smoothPath(outline))
      context.strokePath()
      let eyeHeight: CGFloat = enabled ? 2.8 : 2.2
      for x in [7.3, 10.7] {
        context.fillEllipse(in: CGRect(x: x - 0.9, y: 9.8, width: 1.8, height: eyeHeight))
      }
      context.setLineWidth(1.2)
      context.setLineCap(.round)
      context.move(to: CGPoint(x: 7, y: enabled ? 7.6 : 6.6))
      context.addCurve(
        to: CGPoint(x: 11, y: enabled ? 7.6 : 6.6),
        control1: CGPoint(x: 8.1, y: enabled ? 6 : 8.2),
        control2: CGPoint(x: 9.9, y: enabled ? 6 : 8.2)
      )
      context.strokePath()
      if warning {
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(x: 11.4, y: 11.4, width: 7, height: 7))
        context.setBlendMode(.normal)
        context.fill(CGRect(x: 14.2, y: 14.4, width: 1.4, height: 3.4))
        context.fillEllipse(in: CGRect(x: 14.2, y: 12.2, width: 1.4, height: 1.4))
      }
      return true
    }
    image.isTemplate = true
    return image
  }
}
