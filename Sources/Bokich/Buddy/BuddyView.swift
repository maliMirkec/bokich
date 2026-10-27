import AppKit

final class BuddyView: NSView {
  static let blobSize: CGFloat = 28
  private static let sleepAfter: TimeInterval = 600
  private static let winkHold: TimeInterval = 0.6
  private static let dragThreshold: CGFloat = 3
  private static let squish = CATransform3DMakeScale(1.08, 0.92, 1)
  private static let bounceSquish = CATransform3DMakeScale(1.15, 0.85, 1)
  private static let faceHold: TimeInterval = 1

  private let bodyLayer = CALayer()
  private let shadowLayer = CAShapeLayer()
  private let blobLayer = CAShapeLayer()
  private let faceLayer = FaceLayer()
  private var shape: BlobShape
  private var blinkTimer: Timer?
  private var sleepTimer: Timer?
  private var lastClick = Date()
  private var background: NSColor?
  private var dragStart: NSPoint?
  private var windowStart: NSPoint?
  private var isDragging = false
  var isOff = !Settings.enabled {
    didSet { faceLayer.base = restingFace }
  }
  var onDragStart: (() -> Void)?
  var onDragEnd: (() -> Void)?
  var onClick: (() -> Void)?

  override init(frame: NSRect) {
    if let saved = Settings.blobShape, saved.isValid {
      shape = saved
    } else {
      shape = BlobShape.random()
      Settings.blobShape = shape
    }
    super.init(frame: frame)
    wantsLayer = true
    applyStyle(animated: false)
    bodyLayer.addSublayer(shadowLayer)
    bodyLayer.addSublayer(blobLayer)
    bodyLayer.addSublayer(faceLayer)
    layer?.addSublayer(bodyLayer)
    faceLayer.base = restingFace
    scheduleBlink()
    sleepTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      self?.checkSleep()
    }
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    bodyLayer.bounds = bounds
    bodyLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
    shadowLayer.frame = bounds
    blobLayer.frame = bounds
    faceLayer.frame = bounds
    apply(shape, animated: false)
  }

  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    let scale = window?.backingScaleFactor ?? 2
    layer?.contentsScale = scale
    bodyLayer.contentsScale = scale
    shadowLayer.contentsScale = scale
    blobLayer.contentsScale = scale
    faceLayer.setScale(scale)
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func mouseDown(with event: NSEvent) {
    dragStart = NSEvent.mouseLocation
    windowStart = window?.frame.origin
    isDragging = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard let dragStart, let windowStart, let window else { return }
    let location = NSEvent.mouseLocation
    let dx = location.x - dragStart.x
    let dy = location.y - dragStart.y
    if !isDragging && hypot(dx, dy) > Self.dragThreshold {
      isDragging = true
      setBodyTransform(Self.squish)
      onDragStart?()
    }
    if isDragging {
      window.setFrameOrigin(NSPoint(x: windowStart.x + dx, y: windowStart.y + dy))
    }
  }

  override func mouseUp(with event: NSEvent) {
    dragStart = nil
    windowStart = nil
    if isDragging {
      isDragging = false
      setBodyTransform(CATransform3DIdentity)
      onDragEnd?()
      return
    }
    lastClick = Date()
    faceLayer.base = restingFace
    morph()
    onClick?()
  }

  private var restingFace: Expression {
    isOff ? .sad : .idle
  }

  func showFace(_ expression: Expression) {
    faceLayer.flash(expression, hold: Self.faceHold)
  }

  func bounce() {
    setBodyTransform(Self.bounceSquish)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
      self?.setBodyTransform(CATransform3DIdentity)
    }
  }

  private func setBodyTransform(_ transform: CATransform3D) {
    let from = bodyLayer.presentation()?.transform ?? bodyLayer.transform
    bodyLayer.add(spring("transform", from: NSValue(caTransform3D: from), to: NSValue(caTransform3D: transform)), forKey: "transform")
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    bodyLayer.transform = transform
    CATransaction.commit()
  }

  func wink() {
    faceLayer.flash(.wink, hold: Self.winkHold)
  }

  private func scheduleBlink() {
    blinkTimer = Timer.scheduledTimer(withTimeInterval: .random(in: 3...7), repeats: false) { [weak self] _ in
      self?.faceLayer.blink()
      self?.scheduleBlink()
    }
  }

  private func checkSleep() {
    if Date().timeIntervalSince(lastClick) > Self.sleepAfter {
      if !isOff { faceLayer.base = .sleepy }
    }
  }

  func setBackground(_ color: NSColor?) {
    background = color
    applyStyle(animated: true)
  }

  private func applyStyle(animated: Bool) {
    let style = ContrastStyle.make(background: background, blob: shape.color)
    CATransaction.begin()
    CATransaction.setDisableActions(!animated)
    CATransaction.setAnimationDuration(0.3)
    blobLayer.strokeColor = style.borderColor.cgColor
    blobLayer.lineWidth = style.borderWidth
    shadowLayer.shadowColor = style.shadowColor.cgColor
    shadowLayer.shadowOpacity = style.shadowOpacity
    shadowLayer.shadowRadius = style.shadowRadius
    shadowLayer.shadowOffset = style.shadowOffset
    CATransaction.commit()
  }

  func morph() {
    let next = BlobShape.random(previousColor: shape.colorIndex)
    shape = next
    Settings.blobShape = next
    apply(next, animated: true)
    applyStyle(animated: true)
  }

  private func apply(_ shape: BlobShape, animated: Bool) {
    let center = CGPoint(x: bounds.midX, y: bounds.midY)
    let path = shape.path(center: center, baseRadius: Self.blobSize / 2)
    let color = shape.color.cgColor
    faceLayer.faceColor = shape.swatch.face.cgColor
    if animated {
      for layer in [shadowLayer, blobLayer] {
        layer.add(spring("path", from: layer.presentation()?.path ?? layer.path, to: path), forKey: "path")
        let fade = CABasicAnimation(keyPath: "fillColor")
        fade.fromValue = layer.presentation()?.fillColor ?? layer.fillColor
        fade.toValue = color
        fade.duration = 0.3
        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(fade, forKey: "fillColor")
      }
    }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for layer in [shadowLayer, blobLayer] {
      layer.path = path
      layer.fillColor = color
    }
    CATransaction.commit()
  }

  private func spring(_ keyPath: String, from: Any?, to: Any?) -> CASpringAnimation {
    let animation = CASpringAnimation(keyPath: keyPath)
    animation.damping = 12
    animation.stiffness = 180
    animation.mass = 1
    animation.fromValue = from
    animation.toValue = to
    animation.duration = animation.settlingDuration
    return animation
  }
}
