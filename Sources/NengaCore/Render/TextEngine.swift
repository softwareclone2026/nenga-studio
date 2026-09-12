import CoreGraphics
import CoreText
import Foundation

/// テキスト 1 ブロック分の組版指定。
public struct TextLayoutOptions: Sendable, Hashable {
    public var font: FontChoice
    public var weight: FontWeight
    public var sizeMM: Double
    public var color: RGBColor
    public var direction: TextDirection
    public var alignment: TextAlignmentOption
    public var letterSpacingMM: Double
    public var lineSpacingMM: Double

    public init(
        font: FontChoice = .mincho,
        weight: FontWeight = .regular,
        sizeMM: Double = 5,
        color: RGBColor = .black,
        direction: TextDirection = .vertical,
        alignment: TextAlignmentOption = .center,
        letterSpacingMM: Double = 0,
        lineSpacingMM: Double = 0
    ) {
        self.font = font
        self.weight = weight
        self.sizeMM = sizeMM
        self.color = color
        self.direction = direction
        self.alignment = alignment
        self.letterSpacingMM = letterSpacingMM
        self.lineSpacingMM = lineSpacingMM
    }
}

/// 縦書き・横書きの組版。縦書きは「1 文字ずつ em ボックスへ置く」方式で
/// 実装し、約物・長音・小書き仮名・算用数字を和文組版の慣例に寄せる。
public enum TextEngine {
    /// 組版結果。実際に使った大きさ（mm）と、描画に必要な情報を持つ。
    public struct Layout {
        public var sizeMM: CGSize
        public var lines: [Line]

        public struct Line {
            public var text: String
            /// 描画開始位置（ベースライン、カード左下原点の mm 座標）
            public var origin: CGPoint
            public var isRotatedRun: Bool
        }
    }

    // MARK: - 計測

    /// 与えられた幅（横書き）または高さ（縦書き）に収まるように折り返して計測する。
    public static func measure(
        _ text: String,
        options: TextLayoutOptions,
        maxWidthMM: Double? = nil,
        maxHeightMM: Double? = nil
    ) -> CGSize {
        switch options.direction {
        case .horizontal:
            let lines = wrapHorizontal(text, options: options, maxWidthMM: maxWidthMM)
            let font = FontResolver.font(options.font, weight: options.weight, sizeMM: options.sizeMM)
            let metrics = fontMetrics(font)
            var width: Double = 0
            for line in lines {
                width = max(width, measureHorizontal(line, font: font, letterSpacingMM: options.letterSpacingMM))
            }
            let lineHeight = Double(metrics.ascent + metrics.descent) / mm.pointsPerMM + options.lineSpacingMM
            let height = lineHeight * Double(max(lines.count, 1))
            return CGSize(width: width, height: height)
        case .vertical:
            let columns = verticalColumns(text, options: options, maxHeightMM: maxHeightMM)
            let columnAdvance = options.sizeMM + options.lineSpacingMM
            let tallest = columns.map(\.height).max() ?? options.sizeMM
            let width = Double(max(columns.count, 1)) * columnAdvance - options.lineSpacingMM
            return CGSize(width: width, height: max(tallest, options.sizeMM))
        }
    }

    // MARK: - 描画

    /// `rect` はカード左上原点の mm 矩形（y は下向き）。
    /// `cardHeightMM` はカードの高さで、Core Graphics 座標への反転に使う。
    @discardableResult
    public static func draw(
        _ text: String,
        options: TextLayoutOptions,
        in rect: CGRect,
        cardHeightMM: Double,
        context: CGContext
    ) -> CGSize {
        let font = FontResolver.font(options.font, weight: options.weight, sizeMM: options.sizeMM)
        switch options.direction {
        case .horizontal:
            return drawHorizontal(text, options: options, font: font, rect: rect, cardHeightMM: cardHeightMM, context: context)
        case .vertical:
            return drawVertical(text, options: options, font: font, rect: rect, cardHeightMM: cardHeightMM, context: context)
        }
    }

    // MARK: - 横書き

    private static func drawHorizontal(
        _ text: String,
        options: TextLayoutOptions,
        font: CTFont,
        rect: CGRect,
        cardHeightMM: Double,
        context: CGContext
    ) -> CGSize {
        let lines = wrapHorizontal(text, options: options, maxWidthMM: Double(rect.width))
        let metrics = fontMetrics(font)
        let ascentMM = Double(metrics.ascent) / mm.pointsPerMM
        let descentMM = Double(metrics.descent) / mm.pointsPerMM
        let lineHeight = ascentMM + descentMM + options.lineSpacingMM
        // rect の上端から順に置く
        var topMM = Double(rect.minY)
        var maxWidth: Double = 0

        for line in lines {
            let width = measureHorizontal(line, font: font, letterSpacingMM: options.letterSpacingMM)
            maxWidth = max(maxWidth, width)
            let xOffset: Double
            switch options.alignment {
            case .leading: xOffset = 0
            case .center: xOffset = (Double(rect.width) - width) / 2
            case .trailing: xOffset = Double(rect.width) - width
            }
            let originX = Double(rect.minX) + max(xOffset, 0)
            let baselineTopMM = topMM + ascentMM
            let baselineY = cardHeightMM - baselineTopMM
            let ctLine = makeLine(
                line,
                font: font,
                color: options.color,
                verticalForms: false,
                letterSpacingMM: options.letterSpacingMM
            )
            drawLine(
                ctLine,
                origin: CGPoint(x: originX, y: baselineY),
                context: context
            )
            topMM += lineHeight
        }
        return CGSize(width: maxWidth, height: lineHeight * Double(max(lines.count, 1)))
    }

    private static func wrapHorizontal(_ text: String, options: TextLayoutOptions, maxWidthMM: Double?) -> [String] {
        let font = FontResolver.font(options.font, weight: options.weight, sizeMM: options.sizeMM)
        var result: [String] = []
        for paragraph in text.components(separatedBy: "\n") {
            if paragraph.isEmpty {
                result.append("")
                continue
            }
            guard let maxWidthMM, maxWidthMM > 0 else {
                result.append(paragraph)
                continue
            }
            var current = ""
            for character in paragraph {
                let candidate = current + String(character)
                if measureHorizontal(candidate, font: font, letterSpacingMM: options.letterSpacingMM) > maxWidthMM, !current.isEmpty {
                    result.append(current)
                    current = String(character)
                } else {
                    current = candidate
                }
            }
            result.append(current)
        }
        return result.isEmpty ? [""] : avoidingWidowLines(result, font: font, letterSpacingMM: options.letterSpacingMM, maxWidthMM: maxWidthMM)
    }

    /// 最終行が 1 文字だけにならないように、前の行から 1 文字送る。
    private static func avoidingWidowLines(
        _ lines: [String],
        font: CTFont,
        letterSpacingMM: Double,
        maxWidthMM: Double?
    ) -> [String] {
        guard let maxWidthMM, lines.count >= 2 else { return lines }
        var lines = lines
        let lastIndex = lines.count - 1
        guard lines[lastIndex].count == 1, lines[lastIndex - 1].count >= 3 else { return lines }
        let previous = lines[lastIndex - 1]
        let moved = String(previous.suffix(1))
        let shortened = String(previous.dropLast())
        let candidate = moved + lines[lastIndex]
        guard measureHorizontal(shortened, font: font, letterSpacingMM: letterSpacingMM) <= maxWidthMM,
              measureHorizontal(candidate, font: font, letterSpacingMM: letterSpacingMM) <= maxWidthMM else {
            return lines
        }
        lines[lastIndex - 1] = shortened
        lines[lastIndex] = candidate
        return lines
    }

    private static func measureHorizontal(_ text: String, font: CTFont, letterSpacingMM: Double) -> Double {
        guard !text.isEmpty else { return 0 }
        let line = makeLine(text, font: font, color: .black, verticalForms: false, letterSpacingMM: 0)
        let width = Double(CTLineGetTypographicBounds(line, nil, nil, nil)) / mm.pointsPerMM
        return width + letterSpacingMM * Double(max(text.count - 1, 0))
    }

    // MARK: - 縦書き

    enum VerticalUnit {
        case character(String)
        /// 算用数字や欧文の連なり（縦書きではまとめて 90 度回す）
        case rotatedRun(String)
    }

    private static func drawVertical(
        _ text: String,
        options: TextLayoutOptions,
        font: CTFont,
        rect: CGRect,
        cardHeightMM: Double,
        context: CGContext
    ) -> CGSize {
        let columns = verticalColumns(text, options: options, maxHeightMM: Double(rect.height))
        let em = options.sizeMM + options.letterSpacingMM
        let columnAdvance = options.sizeMM + options.lineSpacingMM
        // 縦書きは右端の列から左へ進む
        var columnRightMM = Double(rect.maxX)
        var maxColumnHeight: Double = 0

        for column in columns {
            let columnHeight = column.height
            maxColumnHeight = max(maxColumnHeight, columnHeight)
            // 列の書き出し位置（上下の寄せ）
            let startTopMM: Double
            switch options.alignment {
            case .leading: startTopMM = Double(rect.minY)
            case .center: startTopMM = Double(rect.minY) + (Double(rect.height) - columnHeight) / 2
            case .trailing: startTopMM = Double(rect.minY) + (Double(rect.height) - columnHeight)
            }
            let columnLeftMM = columnRightMM - columnAdvance
            let centerX = columnLeftMM + columnAdvance / 2
            var topMM = startTopMM

            for unit in column.units {
                switch unit {
                case .character(let character):
                    let cellCenterY = cardHeightMM - (topMM + options.sizeMM / 2)
                    drawVerticalCharacter(
                        character,
                        font: font,
                        color: options.color,
                        cellCenter: CGPoint(x: centerX, y: cellCenterY),
                        emMM: options.sizeMM,
                        context: context
                    )
                    topMM += em
                case .rotatedRun(let run):
                    let line = makeLine(run, font: font, color: options.color, verticalForms: false, letterSpacingMM: 0)
                    let width = Double(CTLineGetTypographicBounds(line, nil, nil, nil)) / mm.pointsPerMM
                    let centerY = cardHeightMM - (topMM + width / 2)
                    context.saveGState()
                    context.translateBy(x: mm.pt(centerX), y: mm.pt(centerY))
                    context.rotate(by: -CGFloat.pi / 2)
                    let metrics = fontMetrics(font)
                    let ascentMM = Double(metrics.ascent) / mm.pointsPerMM
                    let descentMM = Double(metrics.descent) / mm.pointsPerMM
                    context.textPosition = CGPoint(
                        x: mm.pt(-width / 2),
                        y: mm.pt(-(ascentMM - descentMM) / 2)
                    )
                    CTLineDraw(line, context)
                    context.restoreGState()
                    topMM += width + 0.2
                }
            }
            columnRightMM -= columnAdvance
        }
        let totalWidth = columnAdvance * Double(max(columns.count, 1))
        return CGSize(width: totalWidth, height: maxColumnHeight)
    }

    private static func drawVerticalCharacter(
        _ character: String,
        font: CTFont,
        color: RGBColor,
        cellCenter: CGPoint,
        emMM: Double,
        context: CGContext
    ) {
        // Core Text の縦書き属性は字形ごと 90 度回してしまうため使わず、
        // 通常の字形を自前で回転・寄せて和文の縦組みを作る。
        let line = makeLine(character, font: font, color: color, verticalForms: false, letterSpacingMM: 0)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = Double(CTLineGetTypographicBounds(line, &ascent, &descent, nil)) / mm.pointsPerMM
        let ascentMM = Double(ascent) / mm.pointsPerMM
        let descentMM = Double(descent) / mm.pointsPerMM
        let adjustment = verticalAdjustment(for: character, sizeMM: emMM)
        let originX = -width / 2 + adjustment.dxMM
        let originY = -(ascentMM - descentMM) / 2 + adjustment.dyMM

        context.saveGState()
        context.translateBy(x: mm.pt(Double(cellCenter.x)), y: mm.pt(Double(cellCenter.y)))
        if adjustment.rotationDegrees != 0 {
            context.rotate(by: CGFloat(adjustment.rotationDegrees) * .pi / 180)
        }
        if adjustment.scale != 1 {
            context.scaleBy(x: CGFloat(adjustment.scale), y: CGFloat(adjustment.scale))
        }
        context.textPosition = CGPoint(x: mm.pt(originX), y: mm.pt(originY))
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// 縦書き 1 文字分の字形補正。
    struct VerticalGlyphAdjustment {
        /// 負の値で時計回り（Core Graphics は y が上向きのため）
        var rotationDegrees: Double = 0
        var dxMM: Double = 0
        var dyMM: Double = 0
        var scale: Double = 1
    }

    /// 縦書きで字形を回す約物・長音・括弧と、右上へ寄せる小さな仮名を扱う。
    static func verticalAdjustment(for character: String, sizeMM: Double) -> VerticalGlyphAdjustment {
        var adjustment = VerticalGlyphAdjustment()
        guard let scalar = character.unicodeScalars.first, character.count == 1 else { return adjustment }
        switch scalar {
        case "、", "。", "，", "．":
            // 句読点は右上へ寄せる
            adjustment.dxMM = sizeMM * 0.5
            adjustment.dyMM = sizeMM * 0.5
        case "「", "」", "『", "』", "（", "）", "(", ")", "〔", "〕", "［", "］":
            adjustment.rotationDegrees = -90
        case "ー", "～", "〜", "―", "‐", "–", "—", "｜", "|":
            adjustment.rotationDegrees = -90
        default:
            break
        }
        if isSmallKana(character) {
            // 小書き仮名は右上寄りに置く
            adjustment.dxMM += sizeMM * 0.22
            adjustment.dyMM += sizeMM * 0.08
        }
        return adjustment
    }

    /// 縦書きの 1 列分。実際に描画するときの高さ（mm）を持つ。
    struct VerticalColumn {
        var units: [VerticalUnit]
        var height: Double
    }

    /// 縦書きの列を作る。回転させる欧文・数字は実際の幅で高さを測る。
    static func verticalColumns(
        _ text: String,
        options: TextLayoutOptions,
        maxHeightMM: Double?
    ) -> [VerticalColumn] {
        let font = FontResolver.font(options.font, weight: options.weight, sizeMM: options.sizeMM)
        var columns: [VerticalColumn] = []
        let em = options.sizeMM + options.letterSpacingMM
        let limit = maxHeightMM ?? .greatestFiniteMagnitude

        for paragraph in text.components(separatedBy: "\n") {
            var column: [VerticalUnit] = []
            var used: Double = 0
            func flush() {
                let height = max(used - options.letterSpacingMM, 0)
                columns.append(VerticalColumn(units: column, height: max(height, options.sizeMM)))
                column = []
                used = 0
            }
            for unit in verticalUnits(of: paragraph) {
                let unitAdvance: Double
                switch unit {
                case .character:
                    unitAdvance = em
                case .rotatedRun(let run):
                    let line = makeLine(run, font: font, color: .black, verticalForms: false, letterSpacingMM: 0)
                    unitAdvance = Double(CTLineGetTypographicBounds(line, nil, nil, nil)) / mm.pointsPerMM + 0.2
                }
                if column.isEmpty && unitAdvance > limit {
                    // 1 文字も入らないほど長い塊は、そのまま 1 列にしてあふれさせる
                    column.append(unit)
                    used += unitAdvance
                    flush()
                    continue
                }
                if used + unitAdvance > limit, !column.isEmpty {
                    flush()
                }
                column.append(unit)
                used += unitAdvance
            }
            flush()
        }
        return columns.isEmpty ? [VerticalColumn(units: [.character("")], height: options.sizeMM)] : columns
    }

    /// 段落を「1 文字」または「回転させる欧文・数字の連なり」に分解する。
    static func verticalUnits(of paragraph: String) -> [VerticalUnit] {
        var units: [VerticalUnit] = []
        var run = ""
        func flushRun() {
            guard !run.isEmpty else { return }
            if run.count == 1 {
                units.append(.character(run))
            } else {
                units.append(.rotatedRun(run))
            }
            run = ""
        }
        for character in paragraph {
            if isRotatableInVertical(character) {
                run.append(character)
            } else {
                flushRun()
                units.append(.character(String(character)))
            }
        }
        flushRun()
        return units
    }

    /// 縦書きで 90 度回して組む文字（算用数字・欧文）。
    static func isRotatableInVertical(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        switch scalar.value {
        case 0x30...0x39, 0x41...0x5A, 0x61...0x7A:  // 0-9 A-Z a-z
            return true
        case 0x2B, 0x2D, 0x2E, 0x2F, 0x3A, 0x40, 0x5F:  // + - . / : @ _
            return true
        default:
            return false
        }
    }

    static func isSmallKana(_ text: String) -> Bool {
        guard let character = text.first, text.count == 1 else { return false }
        return "ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ".contains(character)
    }

    // MARK: - 下請け

    private static func makeLine(
        _ text: String,
        font: CTFont,
        color: RGBColor,
        verticalForms: Bool,
        letterSpacingMM: Double
    ) -> CTLine {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        if verticalForms {
            attributes[NSAttributedString.Key(kCTVerticalFormsAttributeName as String)] = true
        }
        if letterSpacingMM != 0 {
            attributes[NSAttributedString.Key(kCTKernAttributeName as String)] = mm.pt(letterSpacingMM)
        }
        let attributed = NSAttributedString(string: text, attributes: attributes)
        return CTLineCreateWithAttributedString(attributed)
    }

    private static func drawLine(_ line: CTLine, origin: CGPoint, context: CGContext) {
        context.textPosition = CGPoint(x: mm.pt(Double(origin.x)), y: mm.pt(Double(origin.y)))
        CTLineDraw(line, context)
    }

    private struct FontMetrics {
        var ascent: CGFloat
        var descent: CGFloat
    }

    private static func fontMetrics(_ font: CTFont) -> FontMetrics {
        FontMetrics(ascent: CTFontGetAscent(font), descent: CTFontGetDescent(font))
    }
}
