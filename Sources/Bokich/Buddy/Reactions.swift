enum Reaction {
  case face(Expression)
  case squish
}

final class Reactions {
  private static let faces: [Expression] = [.wink, .surprised, .tongueOut, .happySquint]

  private var lastGreeting: String?
  private var lastFace: Expression?

  func nextGreeting() -> String {
    let greeting = pick(Greetings.all, avoiding: lastGreeting)
    lastGreeting = greeting
    return greeting
  }

  func nextExtra() -> Reaction? {
    let roll = Double.random(in: 0..<1)
    if roll < 0.35 {
      let face = pick(Self.faces, avoiding: lastFace)
      lastFace = face
      return .face(face)
    }
    if roll < 0.5 {
      return .squish
    }
    return nil
  }

  private func pick<T: Equatable>(_ items: [T], avoiding last: T?) -> T {
    let options = items.filter { $0 != last }
    return (options.isEmpty ? items : options).randomElement()!
  }
}
