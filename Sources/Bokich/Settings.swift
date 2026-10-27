import Foundation

struct BuddyPosition {
  var screenID: Int
  var offsetX: Double
  var offsetY: Double
}

enum Settings {
  private static let defaults = UserDefaults.standard

  static var enabled: Bool {
    get { defaults.object(forKey: "enabled") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "enabled") }
  }

  static var showBuddy: Bool {
    get { defaults.object(forKey: "showBuddy") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "showBuddy") }
  }

  static var closeQuitters: Set<String> {
    get {
      let saved = defaults.stringArray(forKey: "closeQuitters") ?? []
      return Set(saved).union(["com.apple.systempreferences", "com.apple.calculator"])
    }
    set { defaults.set(newValue.sorted(), forKey: "closeQuitters") }
  }

  static var shortcut: Shortcut? {
    get {
      if defaults.bool(forKey: "shortcutOff") { return nil }
      guard let data = defaults.data(forKey: "shortcut") else { return .standard }
      return (try? JSONDecoder().decode(Shortcut.self, from: data)) ?? .standard
    }
    set {
      defaults.set(newValue == nil, forKey: "shortcutOff")
      defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "shortcut")
    }
  }

  static var blobShape: BlobShape? {
    get {
      guard let data = defaults.data(forKey: "blobShape") else { return nil }
      return try? JSONDecoder().decode(BlobShape.self, from: data)
    }
    set {
      let data = newValue.flatMap { try? JSONEncoder().encode($0) }
      defaults.set(data, forKey: "blobShape")
    }
  }

  static var position: BuddyPosition? {
    get {
      guard defaults.object(forKey: "positionScreenID") != nil else { return nil }
      return BuddyPosition(
        screenID: defaults.integer(forKey: "positionScreenID"),
        offsetX: defaults.double(forKey: "positionOffsetX"),
        offsetY: defaults.double(forKey: "positionOffsetY")
      )
    }
    set {
      guard let newValue else {
        for key in ["positionScreenID", "positionOffsetX", "positionOffsetY"] {
          defaults.removeObject(forKey: key)
        }
        return
      }
      defaults.set(newValue.screenID, forKey: "positionScreenID")
      defaults.set(newValue.offsetX, forKey: "positionOffsetX")
      defaults.set(newValue.offsetY, forKey: "positionOffsetY")
    }
  }
}
