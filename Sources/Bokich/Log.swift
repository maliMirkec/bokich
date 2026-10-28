import AppKit
import os

enum Log {
  static let follow = Logger(subsystem: "Bokich", category: "follow")
  static let switcher = Logger(subsystem: "Bokich", category: "switch")
  static let input = Logger(subsystem: "Bokich", category: "input")

  static func name(_ pid: pid_t) -> String {
    let app = NSRunningApplication(processIdentifier: pid)
    return "\(app?.localizedName ?? "?")(\(pid))"
  }
}
