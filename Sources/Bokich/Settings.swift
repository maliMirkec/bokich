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
