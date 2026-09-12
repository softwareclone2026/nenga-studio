import CoreGraphics

/// はがきの寸法はすべて mm で扱い、描画の直前に pt へ変換する。
/// （1 pt = 1/72 inch、1 mm = 72/25.4 pt）
public enum mm {
    public static let pointsPerMM: Double = 72.0 / 25.4

    public static func pt(_ value: Double) -> CGFloat {
        CGFloat(value * pointsPerMM)
    }

    public static func fromPoints(_ points: CGFloat) -> Double {
        Double(points) / pointsPerMM
    }
}

/// 色は Core Graphics 型を持ち回らず、sRGB の 8bit 値で保存する。
public struct RGBColor: Codable, Sendable, Hashable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: Double

    public init(r: UInt8, g: UInt8, b: UInt8, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(hex: String, alpha: Double = 1.0) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        if text.count == 3 {
            text = text.map { "\($0)\($0)" }.joined()
        }
        let value = UInt32(text, radix: 16) ?? 0x000000
        self.r = UInt8((value >> 16) & 0xFF)
        self.g = UInt8((value >> 8) & 0xFF)
        self.b = UInt8(value & 0xFF)
        self.a = alpha
    }

    public var hexString: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }

    public var cgColor: CGColor {
        CGColor(
            srgbRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a)
        )
    }

    public func withAlpha(_ alpha: Double) -> RGBColor {
        RGBColor(r: r, g: g, b: b, a: alpha)
    }

    public static let black = RGBColor(hex: "1A1A1A")
    public static let ink = RGBColor(hex: "222222")
    public static let red = RGBColor(hex: "C1272D")
    public static let vermilion = RGBColor(hex: "D8443C")
    public static let gold = RGBColor(hex: "C9A227")
    public static let white = RGBColor(hex: "FFFFFF")
}
