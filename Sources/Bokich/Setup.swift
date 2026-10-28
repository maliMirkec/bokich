import AppKit

struct SetupCheck {
  let title: String
  let isDone: Bool
  let isRequired: Bool
  let url: String
}

enum Setup {
  private static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  private static let missionControl = "x-apple.systempreferences:com.apple.Desktop-Settings.extension"
  private static let keyboard = "x-apple.systempreferences:com.apple.Keyboard-Settings.extension"
  private static let motion = "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?Motion"

  static func checks() -> [SetupCheck] {
    [
      SetupCheck(title: "Allow Accessibility Access", isDone: Permissions.isTrusted, isRequired: true, url: accessibility),
      SetupCheck(title: "Turn Off Switching to the App's Space", isDone: !switchesToAppSpace, isRequired: false, url: missionControl),
      SetupCheck(title: "Turn On Move Left and Right a Space", isDone: arrowsOn, isRequired: false, url: keyboard),
      SetupCheck(title: desktopTitle, isDone: desktopsOn, isRequired: false, url: keyboard),
      SetupCheck(
        title: "Turn On Reduce Motion",
        isDone: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
        isRequired: false,
        url: motion
      )
    ]
  }

  static func open(_ url: String) {
    guard let url = URL(string: url) else { return }
    NSWorkspace.shared.open(url)
  }

  private static var switchesToAppSpace: Bool {
    let global = UserDefaults.standard.object(forKey: "AppleSpacesSwitchOnActivate") as? Bool
    let dock = UserDefaults(suiteName: "com.apple.dock")?.object(forKey: "workspaces-auto-swoosh") as? Bool
    return global ?? dock ?? true
  }

  private static var arrowsOn: Bool {
    SpaceSwitcher.shortcut(SpaceSwitcher.leftID) != nil && SpaceSwitcher.shortcut(SpaceSwitcher.rightID) != nil
  }

  private static var desktopCount: Int {
    let count = Spaces.displays().flatMap { $0.spaces.filter(\.isDesktop) }.count
    return min(count, SpaceSwitcher.numberedDesktops)
  }

  private static var desktopsOn: Bool {
    (0..<desktopCount).allSatisfy { SpaceSwitcher.shortcut(SpaceSwitcher.firstDesktopID + $0) != nil }
  }

  private static var desktopTitle: String {
    let count = desktopCount
    return count > 1 ? "Turn On Switch to Desktop 1–\(count)" : "Turn On Switch to Desktop 1"
  }
}
