import CoreGraphics
import Foundation

/// はがきの用紙規格。官製はがきは 100×148mm（横位置で 148×100mm）。
public struct PostcardPaper: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// 官製はがき（郵便番号枠が印刷済み）
        case official
        /// 私製はがき・無地はがき（枠も印刷する）
        case plain
        /// インクジェット紙など官製と同じ枠付き
        case inkjet

        public var label: String {
            switch self {
            case .official: "官製はがき"
            case .plain: "無地はがき（私製）"
            case .inkjet: "インクジェットはがき"
            }
        }

        public var hasPrintedPostalFrame: Bool {
            self != .plain
        }
    }

    public var widthMM: Double
    public var heightMM: Double
    public var kind: Kind

    public init(widthMM: Double = 148, heightMM: Double = 100, kind: Kind = .official) {
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.kind = kind
    }

    public static let standard = PostcardPaper()

    /// 印刷時の用紙サイズ（縦送り）。はがきは短辺 100mm を幅にして給紙する。
    public var portraitSize: CGSize {
        CGSize(width: mm.pt(heightMM), height: mm.pt(widthMM))
    }

    public var landscapeSize: CGSize {
        CGSize(width: mm.pt(widthMM), height: mm.pt(heightMM))
    }
}

/// 郵便番号枠。官製はがきは赤い枠が印刷済みなので、数字だけを重ねる。
/// プリンタやはがきの個体差はここを微調整して合わせる。
public struct PostalCodeFrameSpec: Codable, Sendable, Hashable {
    public var boxCount: Int
    public var boxWidthMM: Double
    public var boxHeightMM: Double
    public var lineWidthMM: Double
    public var leftMM: Double
    public var topMM: Double
    public var digitSizeMM: Double
    public var showsFrame: Bool
    public var showsDigits: Bool

    public init(
        boxCount: Int = 7,
        boxWidthMM: Double = 5.7,
        boxHeightMM: Double = 8.0,
        lineWidthMM: Double = 0.2,
        leftMM: Double = 29.0,
        topMM: Double = 5.0,
        digitSizeMM: Double = 6.2,
        showsFrame: Bool = true,
        showsDigits: Bool = true
    ) {
        self.boxCount = boxCount
        self.boxWidthMM = boxWidthMM
        self.boxHeightMM = boxHeightMM
        self.lineWidthMM = lineWidthMM
        self.leftMM = leftMM
        self.topMM = topMM
        self.digitSizeMM = digitSizeMM
        self.showsFrame = showsFrame
        self.showsDigits = showsDigits
    }

    public var totalWidthMM: Double { boxWidthMM * Double(boxCount) }

    /// 枠の矩形（はがき左上を原点とした mm 座標、y は下向き）。
    public func boxRect(index: Int) -> CGRect {
        CGRect(
            x: leftMM + boxWidthMM * Double(index),
            y: topMM,
            width: boxWidthMM,
            height: boxHeightMM
        )
    }

    public func frameRect() -> CGRect {
        CGRect(x: leftMM, y: topMM, width: totalWidthMM, height: boxHeightMM)
    }

    /// 7 桁の数字を各枠の中央に配置する。7 桁に満たない場合は左詰め。
    public func digitPositions(for code: String) -> [(rect: CGRect, character: String)] {
        let digits = code.filter { $0.isNumber }
        var result: [(CGRect, String)] = []
        for index in 0..<boxCount {
            let box = boxRect(index: index)
            let character: String = index < digits.count
                ? String(Array(digits)[index])
                : ""
            let width = boxWidthMM * 0.62
            let height = boxHeightMM * 0.78
            let rect = CGRect(
                x: box.midX - width / 2,
                y: box.midY - height / 2,
                width: width,
                height: height
            )
            result.append((rect, character))
        }
        return result
    }
}
