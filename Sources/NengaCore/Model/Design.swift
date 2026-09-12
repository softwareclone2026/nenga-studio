import CoreGraphics
import CoreText
import Foundation

/// 組み込みの日本語フォント。環境に無い場合は自動で代替する。
public enum FontChoice: Codable, Sendable, Hashable, CaseIterable {
    case mincho
    case kaku
    case maru
    case notoSansJP
    case custom(String)

    public static var allCases: [FontChoice] { [.mincho, .kaku, .maru, .notoSansJP] }

    public var displayName: String {
        switch self {
        case .mincho: "明朝体"
        case .kaku: "ゴシック体"
        case .maru: "丸ゴシック体"
        case .notoSansJP: "Noto Sans JP"
        case .custom(let name): name
        }
    }

    public var detailText: String {
        switch self {
        case .mincho: "ヒラギノ明朝 ProN"
        case .kaku: "ヒラギノ角ゴシック"
        case .maru: "ヒラギノ丸ゴ ProN"
        case .notoSansJP: "Noto Sans JP"
        case .custom: "システムのフォント"
        }
    }

    public func postScriptName(weight: FontWeight) -> String {
        switch self {
        case .mincho:
            weight == .bold ? "HiraMinProN-W6" : "HiraMinProN-W3"
        case .kaku:
            weight == .bold ? "HiraginoSans-W6" : "HiraginoSans-W3"
        case .maru:
            "HiraMaruProN-W4"
        case .notoSansJP:
            weight == .bold ? "NotoSansJP-Bold" : "NotoSansJP-Regular"
        case .custom(let name):
            name
        }
    }
}

public enum FontWeight: String, Codable, Sendable, Hashable, CaseIterable {
    case regular
    case bold

    public var label: String { self == .bold ? "太字" : "標準" }
}

/// フォント名を Core Text のフォントに解決する。見つからない場合は日本語が
/// 出せるフォントへ段階的に落とす。
public enum FontResolver {
    public static func font(_ choice: FontChoice, weight: FontWeight, sizeMM: Double) -> CTFont {
        let size = mm.pt(sizeMM)
        let requested = choice.postScriptName(weight: weight)
        if let font = existingFont(named: requested, size: size) {
            return font
        }
        // 太字が無いファミリは標準ウェイトで代替する
        if weight == .bold {
            let regular = choice.postScriptName(weight: .regular)
            if let font = existingFont(named: regular, size: size) {
                return font
            }
        }
        for fallback in ["HiraginoSans-W3", "HiraginoMinW3", "HiraMinProN-W3", "HiraginoKakuGothicProN-W3"] {
            if let font = existingFont(named: fallback, size: size) {
                return font
            }
        }
        return CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    private static func existingFont(named name: String, size: CGFloat) -> CTFont? {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let actual = CTFontCopyPostScriptName(font) as String
        guard actual.caseInsensitiveCompare(name) == .orderedSame else { return nil }
        return font
    }

    /// フォント選択 UI 用。インストール済みの日本語フォント名を列挙する。
    public static func installedJapaneseFamilyNames() -> [String] {
        let names = ["Hiragino Mincho ProN", "Hiragino Sans", "Hiragino Maru Gothic ProN", "Noto Sans JP"]
        return names.filter { family in
            let font = CTFontCreateWithName(family as CFString, 12, nil)
            let actual = CTFontCopyFamilyName(font) as String
            return actual.caseInsensitiveCompare(family) == .orderedSame
        }
    }
}

public enum TextDirection: String, Codable, Sendable, Hashable, CaseIterable {
    case horizontal
    case vertical

    public var label: String { self == .vertical ? "縦書き" : "横書き" }
}

public enum TextAlignmentOption: String, Codable, Sendable, Hashable, CaseIterable {
    case leading
    case center
    case trailing

    public var label: String {
        switch self {
        case .leading: "左寄せ"
        case .center: "中央"
        case .trailing: "右寄せ"
        }
    }
}

/// 和風の配色。テンプレートの雰囲気づくりに使う。
public struct Palette: Codable, Sendable, Hashable {
    public var name: String
    public var primary: RGBColor
    public var secondary: RGBColor
    public var accent: RGBColor
    public var ink: RGBColor
    public var paper: RGBColor

    public init(name: String, primary: RGBColor, secondary: RGBColor, accent: RGBColor, ink: RGBColor, paper: RGBColor) {
        self.name = name
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.ink = ink
        self.paper = paper
    }

    public static let kohaku = Palette(
        name: "紅白金",
        primary: RGBColor(hex: "C1272D"),
        secondary: RGBColor(hex: "E8A0A5"),
        accent: RGBColor(hex: "C9A227"),
        ink: RGBColor(hex: "2A2320"),
        paper: RGBColor(hex: "FFFDF7")
    )

    public static let ai = Palette(
        name: "藍と金",
        primary: RGBColor(hex: "1F3A63"),
        secondary: RGBColor(hex: "6E86A8"),
        accent: RGBColor(hex: "C9A227"),
        ink: RGBColor(hex: "1B2430"),
        paper: RGBColor(hex: "FBFCFE")
    )

    public static let matcha = Palette(
        name: "抹茶と生成り",
        primary: RGBColor(hex: "4C6B41"),
        secondary: RGBColor(hex: "9BB08A"),
        accent: RGBColor(hex: "C4A26A"),
        ink: RGBColor(hex: "2B3026"),
        paper: RGBColor(hex: "F7F4E9")
    )

    public static let momo = Palette(
        name: "桃と金",
        primary: RGBColor(hex: "D96A8A"),
        secondary: RGBColor(hex: "F3C1CE"),
        accent: RGBColor(hex: "C9A227"),
        ink: RGBColor(hex: "3A2A30"),
        paper: RGBColor(hex: "FFF9FA")
    )

    public static let sumi = Palette(
        name: "墨と銀",
        primary: RGBColor(hex: "33383D"),
        secondary: RGBColor(hex: "8B9198"),
        accent: RGBColor(hex: "A8A29A"),
        ink: RGBColor(hex: "22262A"),
        paper: RGBColor(hex: "FCFCFA")
    )

    public static let pop = Palette(
        name: "ポップ",
        primary: RGBColor(hex: "E4572E"),
        secondary: RGBColor(hex: "F3B700"),
        accent: RGBColor(hex: "2A9D8F"),
        ink: RGBColor(hex: "2B2D42"),
        paper: RGBColor(hex: "FFFDF5")
    )

    public static let all: [Palette] = [.kohaku, .ai, .matcha, .momo, .sumi, .pop]
}

/// 和のモチーフ。すべてベクター描画なので、拡大しても印刷でぼやけない。
public enum MotifKind: String, Codable, Sendable, Hashable, CaseIterable {
    case zodiacAnimal      // その年の干支（2027 なら羊のイラスト）
    case zodiacKanji       // 干支の漢字を円相で囲んだもの
    case pine              // 松
    case bamboo            // 竹
    case plum              // 梅
    case pineBambooPlum    // 松竹梅
    case fuji              // 富士山と日の出
    case nandina           // 南天
    case mizuhiki          // 水引
    case fan               // 扇
    case goldCloud         // 金雲
    case asanoha           // 麻の葉文様
    case shippo            // 七宝文様
    case snowRing          // 雪輪
    case kadomatsu         // 門松
    case greeting          // 賀詞の飾り罫

    public var label: String {
        switch self {
        case .zodiacAnimal: "干支のイラスト"
        case .zodiacKanji: "干支の漢字"
        case .pine: "松"
        case .bamboo: "竹"
        case .plum: "梅"
        case .pineBambooPlum: "松竹梅"
        case .fuji: "富士山"
        case .nandina: "南天"
        case .mizuhiki: "水引"
        case .fan: "扇"
        case .goldCloud: "金雲"
        case .asanoha: "麻の葉"
        case .shippo: "七宝"
        case .snowRing: "雪輪"
        case .kadomatsu: "門松"
        case .greeting: "飾り罫"
        }
    }

    public static let drawingMotifs: [MotifKind] = [
        .zodiacAnimal, .zodiacKanji, .pine, .bamboo, .plum, .pineBambooPlum,
        .fuji, .nandina, .mizuhiki, .fan, .kadomatsu, .snowRing,
    ]

    public static let patternMotifs: [MotifKind] = [.goldCloud, .asanoha, .shippo, .greeting]
}

public struct ElementFrame: Codable, Sendable, Hashable {
    /// はがき左上を原点とした mm 座標（y は下向き）
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rotationDegrees: Double

    public init(x: Double, y: Double, width: Double, height: Double, rotationDegrees: Double = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
    }

    public var centerX: Double { x + width / 2 }
    public var centerY: Double { y + height / 2 }
}

public struct TextElement: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var frame: ElementFrame
    public var text: String
    public var font: FontChoice
    public var weight: FontWeight
    public var sizeMM: Double
    public var color: RGBColor
    public var direction: TextDirection
    public var alignment: TextAlignmentOption
    public var letterSpacingMM: Double
    public var lineSpacingMM: Double
    public var usesPlaceholders: Bool
    public var opacity: Double
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        name: String = "テキスト",
        frame: ElementFrame,
        text: String,
        font: FontChoice = .mincho,
        weight: FontWeight = .regular,
        sizeMM: Double = 6,
        color: RGBColor = .black,
        direction: TextDirection = .vertical,
        alignment: TextAlignmentOption = .center,
        letterSpacingMM: Double = 0,
        lineSpacingMM: Double = 0,
        usesPlaceholders: Bool = false,
        opacity: Double = 1,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.text = text
        self.font = font
        self.weight = weight
        self.sizeMM = sizeMM
        self.color = color
        self.direction = direction
        self.alignment = alignment
        self.letterSpacingMM = letterSpacingMM
        self.lineSpacingMM = lineSpacingMM
        self.usesPlaceholders = usesPlaceholders
        self.opacity = opacity
        self.isLocked = isLocked
    }
}

public enum ShapeKind: String, Codable, Sendable, Hashable, CaseIterable {
    case rectangle
    case roundedRectangle
    case ellipse
    case line
    case dashedLine

    public var label: String {
        switch self {
        case .rectangle: "四角"
        case .roundedRectangle: "角丸四角"
        case .ellipse: "円・だ円"
        case .line: "直線"
        case .dashedLine: "点線"
        }
    }
}

public struct ShapeElement: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var frame: ElementFrame
    public var kind: ShapeKind
    public var fill: RGBColor?
    public var stroke: RGBColor?
    public var strokeWidthMM: Double
    public var cornerRadiusMM: Double
    public var opacity: Double
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        name: String = "図形",
        frame: ElementFrame,
        kind: ShapeKind = .rectangle,
        fill: RGBColor? = nil,
        stroke: RGBColor? = .black,
        strokeWidthMM: Double = 0.4,
        cornerRadiusMM: Double = 3,
        opacity: Double = 1,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.kind = kind
        self.fill = fill
        self.stroke = stroke
        self.strokeWidthMM = strokeWidthMM
        self.cornerRadiusMM = cornerRadiusMM
        self.opacity = opacity
        self.isLocked = isLocked
    }
}

public struct MotifElement: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var frame: ElementFrame
    public var kind: MotifKind
    public var paletteName: String
    /// 一部のモチーフで使う塗り色の上書き
    public var overrideColor: RGBColor?
    public var lineWidthMM: Double
    public var opacity: Double
    public var isLocked: Bool

    public init(
        id: UUID = UUID(),
        name: String? = nil,
        frame: ElementFrame,
        kind: MotifKind,
        paletteName: String = Palette.kohaku.name,
        overrideColor: RGBColor? = nil,
        lineWidthMM: Double = 0.5,
        opacity: Double = 1,
        isLocked: Bool = false
    ) {
        self.id = id
        self.name = name ?? kind.label
        self.frame = frame
        self.kind = kind
        self.paletteName = paletteName
        self.overrideColor = overrideColor
        self.lineWidthMM = lineWidthMM
        self.opacity = opacity
        self.isLocked = isLocked
    }

    public var palette: Palette {
        Palette.all.first { $0.name == paletteName } ?? .kohaku
    }
}

public struct ImageElement: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var frame: ElementFrame
    /// パッケージ内 assets/ のファイル名
    public var assetFileName: String
    public var opacity: Double
    public var isLocked: Bool
    public var cornerRadiusMM: Double

    public init(
        id: UUID = UUID(),
        name: String = "写真",
        frame: ElementFrame,
        assetFileName: String,
        opacity: Double = 1,
        isLocked: Bool = false,
        cornerRadiusMM: Double = 0
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.assetFileName = assetFileName
        self.opacity = opacity
        self.isLocked = isLocked
        self.cornerRadiusMM = cornerRadiusMM
    }
}

public enum DesignElement: Codable, Sendable, Hashable, Identifiable {
    case text(TextElement)
    case shape(ShapeElement)
    case motif(MotifElement)
    case image(ImageElement)

    public var id: UUID {
        switch self {
        case .text(let value): value.id
        case .shape(let value): value.id
        case .motif(let value): value.id
        case .image(let value): value.id
        }
    }

    public var name: String {
        get {
            switch self {
            case .text(let value): value.name
            case .shape(let value): value.name
            case .motif(let value): value.name
            case .image(let value): value.name
            }
        }
        set {
            switch self {
            case .text(var value): value.name = newValue; self = .text(value)
            case .shape(var value): value.name = newValue; self = .shape(value)
            case .motif(var value): value.name = newValue; self = .motif(value)
            case .image(var value): value.name = newValue; self = .image(value)
            }
        }
    }

    public var frame: ElementFrame {
        get {
            switch self {
            case .text(let value): value.frame
            case .shape(let value): value.frame
            case .motif(let value): value.frame
            case .image(let value): value.frame
            }
        }
        set {
            switch self {
            case .text(var value): value.frame = newValue; self = .text(value)
            case .shape(var value): value.frame = newValue; self = .shape(value)
            case .motif(var value): value.frame = newValue; self = .motif(value)
            case .image(var value): value.frame = newValue; self = .image(value)
            }
        }
    }

    public var opacity: Double {
        get {
            switch self {
            case .text(let value): value.opacity
            case .shape(let value): value.opacity
            case .motif(let value): value.opacity
            case .image(let value): value.opacity
            }
        }
        set {
            switch self {
            case .text(var value): value.opacity = newValue; self = .text(value)
            case .shape(var value): value.opacity = newValue; self = .shape(value)
            case .motif(var value): value.opacity = newValue; self = .motif(value)
            case .image(var value): value.opacity = newValue; self = .image(value)
            }
        }
    }

    public var isLocked: Bool {
        get {
            switch self {
            case .text(let value): value.isLocked
            case .shape(let value): value.isLocked
            case .motif(let value): value.isLocked
            case .image(let value): value.isLocked
            }
        }
        set {
            switch self {
            case .text(var value): value.isLocked = newValue; self = .text(value)
            case .shape(var value): value.isLocked = newValue; self = .shape(value)
            case .motif(var value): value.isLocked = newValue; self = .motif(value)
            case .image(var value): value.isLocked = newValue; self = .image(value)
            }
        }
    }

    public var kindLabel: String {
        switch self {
        case .text: "テキスト"
        case .shape: "図形"
        case .motif(let value): value.kind.label
        case .image: "画像"
        }
    }

    public var symbolName: String {
        switch self {
        case .text: "textformat"
        case .shape: "square.on.circle"
        case .motif: "sparkles"
        case .image: "photo"
        }
    }
}

/// 文面（裏面）1 ページ分。はがきは 1 ページなので要素の配列だけを持つ。
public struct DesignPage: Codable, Sendable, Hashable {
    public var paperColor: RGBColor
    public var elements: [DesignElement]
    public var templateID: String?

    public init(paperColor: RGBColor = RGBColor(hex: "FFFDF8"), elements: [DesignElement] = [], templateID: String? = nil) {
        self.paperColor = paperColor
        self.elements = elements
        self.templateID = templateID
    }

    public subscript(id: UUID) -> DesignElement? {
        get { elements.first { $0.id == id } }
        set {
            guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
            if let newValue {
                elements[index] = newValue
            } else {
                elements.remove(at: index)
            }
        }
    }

    public mutating func bringForward(_ id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }), index < elements.count - 1 else { return }
        elements.swapAt(index, index + 1)
    }

    public mutating func sendBackward(_ id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }), index > 0 else { return }
        elements.swapAt(index, index - 1)
    }

    public mutating func bringToFront(_ id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        let element = elements.remove(at: index)
        elements.append(element)
    }

    public mutating func sendToBack(_ id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        let element = elements.remove(at: index)
        elements.insert(element, at: 0)
    }
}

/// 差し込み用のプレースホルダ展開。
public enum Placeholder {
    public static let tokens = ["{姓}", "{名}", "{氏名}", "{連名}", "{住所}", "{年号}", "{干支}", "{前年}"]

    public static func expand(
        _ text: String,
        contact: Contact?,
        yearInfo: YearInfo,
        includeHonorific: Bool = false
    ) -> String {
        var result = text
        let family = contact?.familyName ?? ""
        let given = contact?.givenName ?? ""
        let full = contact?.fullName ?? ""
        let honorific = includeHonorific ? (contact?.honorific.rawValue ?? "") : ""
        let coRecipients = (contact?.coRecipients ?? [])
            .map { $0.name + (includeHonorific ? $0.honorific.rawValue : "") }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let replacements: [String: String] = [
            "{姓}": family,
            "{名}": given,
            "{氏名}": full + honorific,
            "{連名}": coRecipients,
            "{住所}": contact?.fullAddress ?? "",
            "{年号}": yearInfo.wareki,
            "{干支}": yearInfo.zodiac.kanji,
            "{前年}": yearInfo.previousYearInfo.wareki,
        ]
        for (token, value) in replacements {
            result = result.replacingOccurrences(of: token, with: value)
        }
        return result
    }
}
