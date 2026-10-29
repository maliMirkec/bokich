import AppKit

struct Space {
  let id: UInt64
  let isDesktop: Bool
}

struct DisplaySpaces {
  let identifier: String
  let spaces: [Space]
  let current: UInt64
}

enum Spaces {
  private typealias MainConnection = @convention(c) () -> Int32
  private typealias CopyDisplaySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?
  private typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?

  private static let allSpacesMask: Int32 = 7
  private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
  private static let mainConnection = symbol("SLSMainConnectionID", as: MainConnection.self)
  private static let copyDisplaySpaces = symbol("SLSCopyManagedDisplaySpaces", as: CopyDisplaySpaces.self)
  private static let copySpacesForWindows = symbol("SLSCopySpacesForWindows", as: CopySpacesForWindows.self)

  static func displays() -> [DisplaySpaces] {
    guard let connection = mainConnection?(), let copy = copyDisplaySpaces,
          let list = copy(connection)?.takeRetainedValue() as? [[String: Any]] else { return [] }
    return list.compactMap { info in
      guard let identifier = info["Display Identifier"] as? String,
            let currentInfo = info["Current Space"] as? [String: Any],
            let current = (currentInfo["ManagedSpaceID"] as? NSNumber)?.uint64Value,
            let spacesInfo = info["Spaces"] as? [[String: Any]] else { return nil }
      let spaces = spacesInfo.compactMap { space -> Space? in
        guard let id = (space["ManagedSpaceID"] as? NSNumber)?.uint64Value else { return nil }
        return Space(id: id, isDesktop: (space["type"] as? NSNumber)?.intValue == 0)
      }
      return DisplaySpaces(identifier: identifier, spaces: spaces, current: current)
    }
  }

  static func spaces(for window: CGWindowID) -> [UInt64] {
    guard let connection = mainConnection?(), let copy = copySpacesForWindows,
          let list = copy(connection, allSpacesMask, [window] as CFArray)?
            .takeRetainedValue() as? [NSNumber] else { return [] }
    return list.map(\.uint64Value)
  }

  static func mouseDisplayIdentifier() -> String? {
    let mouse = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) else { return nil }
    return identifier(of: screen)
  }

  static func screen(for identifier: String) -> NSScreen? {
    NSScreen.screens.first { Self.identifier(of: $0)?.caseInsensitiveCompare(identifier) == .orderedSame }
  }

  private static func identifier(of screen: NSScreen) -> String? {
    guard let id = screen.displayID,
          let uuid = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(id))?.takeRetainedValue() else { return nil }
    return CFUUIDCreateString(nil, uuid) as String
  }

  private static func symbol<T>(_ name: String, as type: T.Type) -> T? {
    guard let skyLight, let pointer = dlsym(skyLight, name) else { return nil }
    return unsafeBitCast(pointer, to: type)
  }
}
