import AppKit

final class FaceLayer: CALayer {
  private static let eyeOffsetX: CGFloat = 3.8
  private static let eyeOffsetY: CGFloat = 2
  private static let mouthOffsetY: CGFloat = -3.2
  private static let morphDuration: CFTimeInterval = 0.18
  private static let blinkDuration: CFTimeInterval = 0.15

  private let leftEye = CAShapeLayer()
  private let rightEye = CAShapeLayer()
  private let mouth = CAShapeLayer()
  private let tongue = CAShapeLayer()
  private var flashID = 0
  private var isFlashing = false
  private(set) var current: Expression = .idle

  var base: Expression = .idle {
    didSet {
      if !isFlashing && base != oldValue { show(base, animated: true) }
    }
  }

  var faceColor: CGColor = NSColor.black.cgColor {
    didSet {
      for layer in [leftEye, rightEye, mouth] {
        layer.fillColor = faceColor
      }
    }
  }

  override init() {
    super.init()
    tongue.fillColor = Palette.tongue.cgColor
    tongue.opacity = 0
    for layer in [mouth, leftEye, rightEye] {
      layer.fillColor = faceColor
    }
    for layer in [tongue, mouth, leftEye, rightEye] {
      addSublayer(layer)
    }
  }

  override init(layer: Any) {
    super.init(layer: layer)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var canBlink: Bool {
    !isFlashing && current == .idle
  }

  func setScale(_ scale: CGFloat) {
    contentsScale = scale
    for layer in [leftEye, rightEye, mouth, tongue] {
      layer.contentsScale = scale
    }
  }

  override func layoutSublayers() {
    super.layoutSublayers()
    for layer in [leftEye, rightEye, mouth, tongue] {
      layer.frame = bounds
    }
    show(current, animated: false)
  }

  func show(_ expression: Expression, animated: Bool) {
    current = expression
    let face = expression.face
    update(leftEye, to: eyePath(face.leftEye, side: -1), animated: animated)
    update(rightEye, to: eyePath(face.rightEye, side: 1), animated: animated)
    update(mouth, to: mouthPath(face.mouth), animated: animated)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    tongue.path = tonguePath(face.mouth)
    CATransaction.commit()
    CATransaction.begin()
    CATransaction.setDisableActions(!animated)
    tongue.opacity = face.tongue ? 1 : 0
    CATransaction.commit()
  }

  func blink() {
    guard canBlink else { return }
    let open = Expression.idle.face
    let closed = Expression.blink.face
    for (layer, side) in [(leftEye, CGFloat(-1)), (rightEye, CGFloat(1))] {
      let eye = side < 0 ? \FaceShape.leftEye : \FaceShape.rightEye
      let animation = CAKeyframeAnimation(keyPath: "path")
      animation.values = [
        eyePath(open[keyPath: eye], side: side),
        eyePath(closed[keyPath: eye], side: side),
        eyePath(open[keyPath: eye], side: side)
      ]
      animation.duration = Self.blinkDuration
      layer.add(animation, forKey: "blink")
    }
  }

  func flash(_ expression: Expression, hold: TimeInterval) {
    flashID += 1
    let id = flashID
    isFlashing = true
    show(expression, animated: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + hold) { [weak self] in
      guard let self, self.flashID == id else { return }
      self.isFlashing = false
      self.show(self.base, animated: true)
    }
  }

  private var center: CGPoint {
    CGPoint(x: bounds.midX, y: bounds.midY)
  }

  private func update(_ layer: CAShapeLayer, to path: CGPath, animated: Bool) {
    if animated {
      let animation = CABasicAnimation(keyPath: "path")
      animation.fromValue = layer.presentation()?.path ?? layer.path
      animation.toValue = path
      animation.duration = Self.morphDuration
      animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      layer.add(animation, forKey: "path")
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.path = path
    CATransaction.commit()
  }

  private func eyePath(_ eye: EyeShape, side: CGFloat) -> CGPath {
    let x = center.x + side * Self.eyeOffsetX
    let y = center.y + Self.eyeOffsetY + eye.lift
    let rect = CGRect(x: x - eye.width / 2, y: y - eye.height / 2, width: eye.width, height: eye.height)
    return CGPath(ellipseIn: rect, transform: nil)
  }

  private func mouthPath(_ shape: MouthShape) -> CGPath {
    let y = center.y + Self.mouthOffsetY + shape.lift
    let left = CGPoint(x: center.x - shape.width / 2, y: y)
    let right = CGPoint(x: center.x + shape.width / 2, y: y)
    let dx = shape.width * 0.35
    let path = CGMutablePath()
    path.move(to: left)
    path.addCurve(
      to: right,
      control1: CGPoint(x: center.x - dx, y: y + shape.top),
      control2: CGPoint(x: center.x + dx, y: y + shape.top)
    )
    path.addCurve(
      to: left,
      control1: CGPoint(x: center.x + dx, y: y + shape.bottom),
      control2: CGPoint(x: center.x - dx, y: y + shape.bottom)
    )
    path.closeSubpath()
    return path
  }

  private func tonguePath(_ shape: MouthShape) -> CGPath {
    let y = center.y + Self.mouthOffsetY + shape.lift
    let rect = CGRect(x: center.x - 0.4, y: y - 4.4, width: 3.2, height: 3.4)
    return CGPath(ellipseIn: rect, transform: nil)
  }
}
