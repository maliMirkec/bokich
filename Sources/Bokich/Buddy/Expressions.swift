import CoreGraphics

enum Expression {
  case idle
  case blink
  case wink
  case surprised
  case tongueOut
  case happySquint
  case sleepy
  case sad
}

struct EyeShape {
  var width: CGFloat
  var height: CGFloat
  var lift: CGFloat = 0
}

struct MouthShape {
  var width: CGFloat
  var top: CGFloat
  var bottom: CGFloat
  var lift: CGFloat = 0
}

struct FaceShape {
  var leftEye: EyeShape
  var rightEye: EyeShape
  var mouth: MouthShape
  var tongue = false
}

extension Expression {
  var face: FaceShape {
    let open = EyeShape(width: 3, height: 4)
    let closed = EyeShape(width: 3.6, height: 0.7, lift: -0.5)
    let smile = MouthShape(width: 7, top: -1.2, bottom: -3)
    switch self {
    case .idle:
      return FaceShape(leftEye: open, rightEye: open, mouth: smile)
    case .blink:
      return FaceShape(leftEye: closed, rightEye: closed, mouth: smile)
    case .wink:
      return FaceShape(leftEye: closed, rightEye: open, mouth: MouthShape(width: 8, top: -1.5, bottom: -4.5))
    case .surprised:
      let wide = EyeShape(width: 3.6, height: 5, lift: 0.5)
      return FaceShape(leftEye: wide, rightEye: wide, mouth: MouthShape(width: 3, top: 2.2, bottom: -2.2, lift: -1))
    case .tongueOut:
      return FaceShape(leftEye: open, rightEye: closed, mouth: MouthShape(width: 6, top: -1, bottom: -2.5), tongue: true)
    case .happySquint:
      let squint = EyeShape(width: 3.8, height: 1.4)
      return FaceShape(leftEye: squint, rightEye: squint, mouth: MouthShape(width: 8, top: -1, bottom: -5))
    case .sleepy:
      let heavy = EyeShape(width: 3.4, height: 1, lift: -0.5)
      return FaceShape(leftEye: heavy, rightEye: heavy, mouth: MouthShape(width: 4, top: -0.3, bottom: -1.3, lift: -0.5))
    case .sad:
      let down = EyeShape(width: 2.8, height: 3.4, lift: -0.4)
      return FaceShape(leftEye: down, rightEye: down, mouth: MouthShape(width: 6, top: 2.6, bottom: 1.2, lift: -1.2))
    }
  }
}
