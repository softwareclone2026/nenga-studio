import CoreGraphics
import CoreText
import Foundation

/// モチーフ描画に渡す情報。`rect` は Core Graphics 座標（mm・y は上向き）。
public struct MotifContext: Sendable {
    public var rect: CGRect
    public var palette: Palette
    public var lineWidthMM: Double
    public var overrideColor: RGBColor?
    public var yearInfo: YearInfo

    public init(
        rect: CGRect,
        palette: Palette,
        lineWidthMM: Double = 0.5,
        overrideColor: RGBColor? = nil,
        yearInfo: YearInfo = YearInfo(year: 2027)
    ) {
        self.rect = rect
        self.palette = palette
        self.lineWidthMM = lineWidthMM
        self.overrideColor = overrideColor
        self.yearInfo = yearInfo
    }
}

/// モチーフのベクター描画。図形はすべて単位正方形（y は上向き）で定義し、
/// 縦横比を保つために短辺に合わせた正方形へ写す。
struct MotifPen {
    let ctx: CGContext
    let box: CGRect
    let palette: Palette
    let lineWidthMM: Double
    let override: RGBColor?
    let yearInfo: YearInfo

    init(context: MotifContext, context ctx: CGContext, fillRect: Bool = false) {
        self.ctx = ctx
        self.palette = context.palette
        self.lineWidthMM = context.lineWidthMM
        self.override = context.overrideColor
        self.yearInfo = context.yearInfo
        if fillRect {
            self.box = context.rect
        } else {
            let side = min(context.rect.width, context.rect.height)
            self.box = CGRect(
                x: context.rect.midX - side / 2,
                y: context.rect.midY - side / 2,
                width: side,
                height: side
            )
        }
    }

    /// 同じ描画条件のまま、別の矩形を受け持つペンを作る（複合モチーフ用）。
    init(pen: MotifPen, box: CGRect) {
        self.ctx = pen.ctx
        self.palette = pen.palette
        self.lineWidthMM = pen.lineWidthMM
        self.override = pen.override
        self.yearInfo = pen.yearInfo
        self.box = box
    }

    /// 単位座標（0〜1）で指定した部分矩形を受け持つペン。
    func child(x: Double, y: Double, width: Double, height: Double) -> MotifPen {
        MotifPen(
            pen: self,
            box: CGRect(
                x: box.minX + box.width * CGFloat(x),
                y: box.minY + box.height * CGFloat(y),
                width: box.width * CGFloat(width),
                height: box.height * CGFloat(height)
            )
        )
    }

    // MARK: 座標

    func p(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: box.minX + box.width * CGFloat(x), y: box.minY + box.height * CGFloat(y))
    }

    func l(_ value: Double) -> CGFloat {
        CGFloat(value) * min(box.width, box.height)
    }

    var lineWidth: CGFloat { mm.pt(lineWidthMM) }

    // MARK: 色

    var foliage: RGBColor { override ?? RGBColor(hex: "3F5D45") }
    var wood: RGBColor { RGBColor(hex: "6B4F3A") }
    var blossom: RGBColor { override ?? palette.primary }
    var blossomLight: RGBColor { palette.secondary }
    var gold: RGBColor { palette.accent }
    var ink: RGBColor { palette.ink }

    // MARK: 描画

    func stroke(_ path: CGPath, color: RGBColor, width: Double? = nil, cap: CGLineCap = .round, join: CGLineJoin = .round) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width.map { mm.pt($0) } ?? lineWidth)
        ctx.setLineCap(cap)
        ctx.setLineJoin(join)
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    func fill(_ path: CGPath, color: RGBColor) {
        ctx.saveGState()
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.restoreGState()
    }

    func fillAndStroke(_ path: CGPath, fill fillColor: RGBColor, stroke strokeColor: RGBColor, width: Double? = nil) {
        fill(path, color: fillColor)
        stroke(path, color: strokeColor, width: width)
    }

    func line(_ a: (Double, Double), _ b: (Double, Double), color: RGBColor, width: Double? = nil, cap: CGLineCap = .round) {
        let path = CGMutablePath()
        path.move(to: p(a.0, a.1))
        path.addLine(to: p(b.0, b.1))
        stroke(path, color: color, width: width, cap: cap)
    }

    func segment(from: CGPoint, to: CGPoint, color: RGBColor, width: Double? = nil, cap: CGLineCap = .round) {
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        stroke(path, color: color, width: width, cap: cap)
    }

    func polygon(_ points: [(Double, Double)], fill fillColor: RGBColor?, stroke strokeColor: RGBColor? = nil, width: Double? = nil) {
        guard points.count > 1 else { return }
        let path = CGMutablePath()
        path.move(to: p(points[0].0, points[0].1))
        for point in points.dropFirst() {
            path.addLine(to: p(point.0, point.1))
        }
        path.closeSubpath()
        if let fillColor { fill(path, color: fillColor) }
        if let strokeColor { stroke(path, color: strokeColor, width: width) }
    }

    func circle(center: (Double, Double), radius: Double, fill fillColor: RGBColor? = nil, stroke strokeColor: RGBColor? = nil, width: Double? = nil) {
        let path = CGPath(
            ellipseIn: CGRect(
                x: box.minX + box.width * CGFloat(center.0 - radius),
                y: box.minY + box.height * CGFloat(center.1 - radius),
                width: box.width * CGFloat(radius * 2),
                height: box.height * CGFloat(radius * 2)
            ),
            transform: nil
        )
        if let fillColor { fill(path, color: fillColor) }
        if let strokeColor { stroke(path, color: strokeColor, width: width) }
    }

    /// 単位座標の楕円。
    func ellipse(center: (Double, Double), rx: Double, ry: Double, rotation: Double = 0, fill fillColor: RGBColor? = nil, stroke strokeColor: RGBColor? = nil, width: Double? = nil) {
        let centerPoint = p(center.0, center.1)
        ctx.saveGState()
        ctx.translateBy(x: centerPoint.x, y: centerPoint.y)
        ctx.rotate(by: CGFloat(rotation) * .pi / 180)
        let rect = CGRect(
            x: -l(rx),
            y: -l(ry),
            width: l(rx) * 2,
            height: l(ry) * 2
        )
        let path = CGPath(ellipseIn: rect, transform: nil)
        if let fillColor { fill(path, color: fillColor) }
        if let strokeColor { stroke(path, color: strokeColor, width: width) }
        ctx.restoreGState()
    }

    func text(_ string: String, font: CTFont, color: RGBColor, center: (Double, Double)) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let point = p(center.0, center.1)
        ctx.saveGState()
        ctx.textPosition = CGPoint(
            x: point.x - width / 2,
            y: point.y - (ascent - descent) / 2
        )
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}

public enum MotifRenderer {
    public static func draw(_ kind: MotifKind, context: MotifContext, in ctx: CGContext) {
        switch kind {
        case .goldCloud:
            drawPattern(context: context, ctx: ctx) { pen in goldCloud(pen) }
        case .asanoha:
            drawPattern(context: context, ctx: ctx) { pen in asanoha(pen) }
        case .shippo:
            drawPattern(context: context, ctx: ctx) { pen in shippo(pen) }
        case .greeting:
            drawPattern(context: context, ctx: ctx) { pen in greetingRule(pen) }
        case .pine:
            drawFigure(context: context, ctx: ctx) { pen in pine(pen) }
        case .bamboo:
            drawFigure(context: context, ctx: ctx) { pen in bamboo(pen) }
        case .plum:
            drawFigure(context: context, ctx: ctx) { pen in plumBranch(pen) }
        case .pineBambooPlum:
            drawFigure(context: context, ctx: ctx) { pen in pineBambooPlum(pen) }
        case .fuji:
            drawFigure(context: context, ctx: ctx) { pen in fuji(pen) }
        case .nandina:
            drawFigure(context: context, ctx: ctx) { pen in nandina(pen) }
        case .mizuhiki:
            drawFigure(context: context, ctx: ctx) { pen in mizuhiki(pen) }
        case .fan:
            drawFigure(context: context, ctx: ctx) { pen in fan(pen) }
        case .snowRing:
            drawFigure(context: context, ctx: ctx) { pen in snowRing(pen) }
        case .kadomatsu:
            drawFigure(context: context, ctx: ctx) { pen in kadomatsu(pen) }
        case .zodiacAnimal:
            if context.yearInfo.zodiac == .hitsuji {
                drawFigure(context: context, ctx: ctx) { pen in sheep(pen) }
            } else {
                drawFigure(context: context, ctx: ctx) { pen in zodiacKanji(pen) }
            }
        case .zodiacKanji:
            drawFigure(context: context, ctx: ctx) { pen in zodiacKanji(pen) }
        }
    }

    private static func drawFigure(context: MotifContext, ctx: CGContext, _ body: (MotifPen) -> Void) {
        let pen = MotifPen(context: context, context: ctx)
        body(pen)
    }

    private static func drawPattern(context: MotifContext, ctx: CGContext, _ body: (MotifPen) -> Void) {
        ctx.saveGState()
        ctx.clip(to: context.rect)
        let pen = MotifPen(context: context, context: ctx, fillRect: true)
        body(pen)
        ctx.restoreGState()
    }

    // MARK: - 金雲

    private static func goldCloud(_ pen: MotifPen) {
        let rect = pen.box
        let scale = min(rect.width, rect.height)
        // 霞（金雲）を 3 段。丸を重ねて柔らかい輪郭にする。
        let bands: [(centerY: Double, thickness: Double, startX: Double, endX: Double, alpha: Double)] = [
            (0.2, 0.5, -0.02, 0.72, 0.5),
            (0.46, 0.62, 0.12, 0.98, 0.85),
            (0.74, 0.46, 0.3, 1.05, 0.45),
        ]
        for band in bands {
            let color = pen.gold.withAlpha(band.alpha)
            let thickness = band.thickness
            let y = rect.minY + rect.height * CGFloat(band.centerY)
            let startX = rect.minX + rect.width * CGFloat(band.startX)
            let endX = rect.minX + rect.width * CGFloat(band.endX)
            let span = max(endX - startX, 1)
            let step = span / 9
            var x = startX
            var index = 0
            // 重なりを 1 つのパスにまとめて塗る（重複部分が濃くならないように）
            let cloud = CGMutablePath()
            while x <= endX {
                // 中央を厚く、端を薄くして霞らしくする
                let position = (x - startX) / span
                let taper = sin(Double(position) * .pi)
                let radius = scale * thickness * CGFloat(0.22 + 0.28 * taper)
                cloud.addEllipse(in: CGRect(
                    x: x - radius,
                    y: y - radius * 0.72,
                    width: radius * 2,
                    height: radius * 1.44
                ))
                if index % 2 == 0 {
                    let bumpRadius = radius * 0.62
                    cloud.addEllipse(in: CGRect(
                        x: x - bumpRadius + step * 0.5,
                        y: y + radius * 0.5,
                        width: bumpRadius * 2,
                        height: bumpRadius * 1.5
                    ))
                }
                x += step
                index += 1
            }
            pen.fill(cloud, color: color)
        }
    }

    /// 霞形の柔らかい雲を 1 つ描く（富士山の麓などで使う）。
    private static func softCloud(_ pen: MotifPen, from startX: Double, to endX: Double, y: Double, thickness: Double, color: RGBColor) {
        let rect = pen.box
        let start = rect.minX + rect.width * CGFloat(startX)
        let end = rect.minX + rect.width * CGFloat(endX)
        let yPoint = rect.minY + rect.height * CGFloat(y)
        let span = max(end - start, 1)
        let step = span / 5
        let cloud = CGMutablePath()
        var x = start
        while x <= end {
            let radius = rect.width * CGFloat(thickness)
            cloud.addEllipse(in: CGRect(x: x - radius, y: yPoint - radius * 0.5, width: radius * 2, height: radius))
            x += step
        }
        pen.fill(cloud, color: color)
    }

    // MARK: - 麻の葉

    private static func asanoha(_ pen: MotifPen) {
        let size = pen.box.height
        let cell = size / 4.6
        let color = pen.override ?? pen.palette.secondary
        let rect = pen.box
        let radius = cell / 2
        let dx = cell * 0.866
        let dy = cell * 1.5
        var row = 0
        var y = rect.minY - cell
        while y < rect.maxY + cell {
            var x = rect.minX - cell + (row % 2 == 0 ? 0 : dx)
            while x < rect.maxX + cell {
                hexagonStar(pen, center: CGPoint(x: x, y: y), radius: radius, color: color)
                x += dx * 2
            }
            y += dy
            row += 1
        }
    }

    private static func hexagonStar(_ pen: MotifPen, center: CGPoint, radius: CGFloat, color: RGBColor) {
        let path = CGMutablePath()
        let vertices: [CGPoint] = (0..<6).map { index in
            let angle = CGFloat(index) * .pi / 3
            return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }
        path.move(to: vertices[0])
        for vertex in vertices.dropFirst() {
            path.addLine(to: vertex)
        }
        path.closeSubpath()
        pen.stroke(path, color: color, width: pen.lineWidthMM * 0.8)

        // 中心から頂点へのスポークと、辺の中点から中心への補助線で麻の葉になる
        let inner = CGMutablePath()
        for index in 0..<6 {
            let a = vertices[index]
            let b = vertices[(index + 1) % 6]
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            inner.move(to: center)
            inner.addLine(to: a)
            inner.move(to: mid)
            inner.addLine(to: center)
        }
        pen.stroke(inner, color: color, width: pen.lineWidthMM * 0.8)
    }

    // MARK: - 七宝

    private static func shippo(_ pen: MotifPen) {
        let rect = pen.box
        let spacing = min(rect.width, rect.height) / 2.4
        let radius = spacing / 1.4142
        let color = pen.override ?? pen.palette.secondary
        var row = 0
        var y = rect.minY - spacing
        while y < rect.maxY + spacing {
            var offset: CGFloat = row % 2 == 0 ? 0 : spacing / 2
            var x = rect.minX - spacing + offset
            while x < rect.maxX + spacing {
                let path = CGPath(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2), transform: nil)
                pen.stroke(path, color: color, width: pen.lineWidthMM * 0.8)
                x += spacing
                offset = 0
            }
            y += spacing
            row += 1
        }
    }

    // MARK: - 飾り罫

    private static func greetingRule(_ pen: MotifPen) {
        let rect = pen.box
        let midY = rect.midY
        let inset = rect.width * 0.06
        let gap = rect.width * 0.12
        let color = pen.override ?? pen.gold
        pen.segment(
            from: CGPoint(x: rect.minX + inset, y: midY),
            to: CGPoint(x: rect.midX - gap, y: midY),
            color: color,
            width: pen.lineWidthMM
        )
        pen.segment(
            from: CGPoint(x: rect.midX + gap, y: midY),
            to: CGPoint(x: rect.maxX - inset, y: midY),
            color: color,
            width: pen.lineWidthMM
        )
        // 中央の梅
        let flowerRadius = min(rect.height * 0.36, gap * 0.5)
        let center = CGPoint(x: rect.midX, y: midY)
        for index in 0..<5 {
            let angle = CGFloat(index) * 2 * .pi / 5 + .pi / 2
            let petalCenter = CGPoint(
                x: center.x + flowerRadius * 0.52 * cos(angle),
                y: center.y + flowerRadius * 0.52 * sin(angle)
            )
            let petal = CGPath(
                ellipseIn: CGRect(
                    x: petalCenter.x - flowerRadius * 0.34,
                    y: petalCenter.y - flowerRadius * 0.34,
                    width: flowerRadius * 0.68,
                    height: flowerRadius * 0.68
                ),
                transform: nil
            )
            pen.fill(petal, color: pen.blossom)
        }
        let core = CGPath(
            ellipseIn: CGRect(x: center.x - flowerRadius * 0.18, y: center.y - flowerRadius * 0.18, width: flowerRadius * 0.36, height: flowerRadius * 0.36),
            transform: nil
        )
        pen.fill(core, color: pen.gold)
        // 左右の葉
        let leafOffset = gap * 1.35
        for direction in [-1.0, 1.0] {
            let leaf = CGMutablePath()
            let base = CGPoint(x: rect.midX + leafOffset * CGFloat(direction), y: midY)
            leaf.move(to: base)
            leaf.addQuadCurve(
                to: CGPoint(x: base.x + leafOffset * 0.55 * CGFloat(direction), y: base.y),
                control: CGPoint(x: base.x + leafOffset * 0.3 * CGFloat(direction), y: base.y + flowerRadius * 0.7)
            )
            leaf.addQuadCurve(
                to: base,
                control: CGPoint(x: base.x + leafOffset * 0.3 * CGFloat(direction), y: base.y - flowerRadius * 0.7)
            )
            pen.fill(leaf, color: pen.foliage)
        }
    }

    // MARK: - 松

    private static func pine(_ pen: MotifPen) {
        let trunk = pen.wood
        // 幹
        let trunkPath = CGMutablePath()
        trunkPath.move(to: pen.p(0.18, 0.05))
        trunkPath.addCurve(
            to: pen.p(0.5, 0.62),
            control1: pen.p(0.28, 0.28),
            control2: pen.p(0.38, 0.42)
        )
        trunkPath.addCurve(
            to: pen.p(0.78, 0.92),
            control1: pen.p(0.6, 0.76),
            control2: pen.p(0.7, 0.86)
        )
        pen.stroke(trunkPath, color: trunk, width: pen.lineWidthMM * 3.4)
        // 枝
        let branch = CGMutablePath()
        branch.move(to: pen.p(0.36, 0.34))
        branch.addQuadCurve(to: pen.p(0.12, 0.52), control: pen.p(0.22, 0.4))
        pen.stroke(branch, color: trunk, width: pen.lineWidthMM * 2.0)
        let branch2 = CGMutablePath()
        branch2.move(to: pen.p(0.48, 0.6))
        branch2.addQuadCurve(to: pen.p(0.86, 0.66), control: pen.p(0.66, 0.68))
        pen.stroke(branch2, color: trunk, width: pen.lineWidthMM * 1.6)

        // 針葉の房
        pineNeedles(pen, center: (0.16, 0.56), radius: 0.2, angle: -20)
        pineNeedles(pen, center: (0.42, 0.72), radius: 0.22, angle: 12)
        pineNeedles(pen, center: (0.66, 0.9), radius: 0.2, angle: -8)
        pineNeedles(pen, center: (0.86, 0.68), radius: 0.17, angle: 28)
    }

    /// `center` と `radius` は単位座標。
    private static func pineNeedles(_ pen: MotifPen, center: (Double, Double), radius: Double, angle: Double) {
        let color = pen.foliage
        let centerPoint = pen.p(center.0, center.1)
        let radius = pen.l(radius)
        let baseAngle = CGFloat(angle) * .pi / 180
        let count = 23
        for index in 0..<count {
            let spread = (CGFloat(index) / CGFloat(count - 1) - 0.5) * .pi * 0.72
            let a = baseAngle + spread + .pi / 2
            let start = CGPoint(
                x: centerPoint.x + cos(a + .pi) * radius * 0.18,
                y: centerPoint.y + sin(a + .pi) * radius * 0.18
            )
            let end = CGPoint(x: centerPoint.x + cos(a) * radius, y: centerPoint.y + sin(a) * radius)
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            pen.stroke(path, color: color, width: pen.lineWidthMM * 0.55, cap: .round)
        }
        let base = CGPath(
            ellipseIn: CGRect(
                x: centerPoint.x - radius * 0.12,
                y: centerPoint.y - radius * 0.12,
                width: radius * 0.24,
                height: radius * 0.24
            ),
            transform: nil
        )
        pen.fill(base, color: pen.wood)
    }

    // MARK: - 竹

    private static func bamboo(_ pen: MotifPen) {
        let stalks: [(Double, Double, Double)] = [
            (0.34, 0.06, 0.94),
            (0.56, 0.1, 0.82),
            (0.74, 0.04, 0.7),
        ]
        for (index, stalk) in stalks.enumerated() {
            let (x, bottom, top) = stalk
            let width = pen.lineWidthMM * (index == 0 ? 3.0 : 2.4)
            let path = CGMutablePath()
            path.move(to: pen.p(x, bottom))
            path.addLine(to: pen.p(x + 0.02, top))
            pen.stroke(path, color: pen.foliage, width: width, cap: .butt)
            // 節
            var y = bottom + 0.1
            while y < top {
                let node = CGMutablePath()
                node.move(to: pen.p(x - 0.035, y))
                node.addLine(to: pen.p(x + 0.055, y))
                pen.stroke(node, color: pen.foliage, width: pen.lineWidthMM * 1.1)
                y += 0.16
            }
            // 枝葉
            bambooLeaves(pen, at: (x + 0.03, top - 0.06), direction: 1, size: 0.2 - Double(index) * 0.02)
            bambooLeaves(pen, at: (x + 0.01, top - 0.26), direction: -1, size: 0.17)
        }
    }

    /// `origin` と `size` は単位座標。
    private static func bambooLeaves(_ pen: MotifPen, at origin: (Double, Double), direction: Double, size: Double) {
        let origin = pen.p(origin.0, origin.1)
        for index in 0..<3 {
            let spread = (Double(index) - 1) * 0.5
            let angle = spread * direction
            let leaf = CGMutablePath()
            let scale = pen.l(size)
            let dx = CGFloat(cos(angle)) * scale
            let dy = CGFloat(sin(angle)) * scale
            leaf.move(to: origin)
            leaf.addQuadCurve(
                to: CGPoint(x: origin.x + dx * CGFloat(direction), y: origin.y + dy * 0.6 + scale * 0.25),
                control: CGPoint(x: origin.x + dx * 0.5 * CGFloat(direction), y: origin.y + dy * 0.2 + scale * 0.35)
            )
            leaf.addQuadCurve(
                to: origin,
                control: CGPoint(x: origin.x + dx * 0.5 * CGFloat(direction), y: origin.y + dy * 0.4 + scale * 0.05)
            )
            pen.fill(leaf, color: pen.foliage)
        }
    }

    // MARK: - 梅

    private static func plumBranch(_ pen: MotifPen) {
        let branch = CGMutablePath()
        branch.move(to: pen.p(0.08, 0.12))
        branch.addCurve(to: pen.p(0.62, 0.5), control1: pen.p(0.28, 0.22), control2: pen.p(0.44, 0.34))
        branch.addCurve(to: pen.p(0.94, 0.78), control1: pen.p(0.74, 0.6), control2: pen.p(0.86, 0.66))
        pen.stroke(branch, color: pen.wood, width: pen.lineWidthMM * 2.6)
        let twig = CGMutablePath()
        twig.move(to: pen.p(0.4, 0.3))
        twig.addQuadCurve(to: pen.p(0.3, 0.62), control: pen.p(0.3, 0.44))
        pen.stroke(twig, color: pen.wood, width: pen.lineWidthMM * 1.4)
        let twig2 = CGMutablePath()
        twig2.move(to: pen.p(0.72, 0.58))
        twig2.addQuadCurve(to: pen.p(0.86, 0.36), control: pen.p(0.84, 0.5))
        pen.stroke(twig2, color: pen.wood, width: pen.lineWidthMM * 1.2)

        plumBlossom(pen, center: (0.28, 0.6), radius: 0.14, color: pen.blossom)
        plumBlossom(pen, center: (0.6, 0.72), radius: 0.12, color: pen.blossomLight)
        plumBlossom(pen, center: (0.84, 0.46), radius: 0.1, color: pen.blossom)
        plumBlossom(pen, center: (0.9, 0.86), radius: 0.085, color: pen.blossomLight)
        // つぼみ
        for bud in [(0.14, 0.34), (0.52, 0.42), (0.72, 0.9)] {
            let point = pen.p(bud.0, bud.1)
            let path = CGPath(
                ellipseIn: CGRect(
                    x: point.x - pen.l(0.022),
                    y: point.y - pen.l(0.028),
                    width: pen.l(0.044),
                    height: pen.l(0.056)
                ),
                transform: nil
            )
            pen.fill(path, color: pen.blossom)
        }
    }

    /// `center` と `radius` は単位座標。
    private static func plumBlossom(_ pen: MotifPen, center: (Double, Double), radius: Double, color: RGBColor) {
        let center = pen.p(center.0, center.1)
        let radius = pen.l(radius)
        for index in 0..<5 {
            let angle = CGFloat(index) * 2 * .pi / 5 + .pi / 2
            let petalCenter = CGPoint(
                x: center.x + radius * 0.62 * cos(angle),
                y: center.y + radius * 0.62 * sin(angle)
            )
            let path = CGPath(
                ellipseIn: CGRect(
                    x: petalCenter.x - radius * 0.44,
                    y: petalCenter.y - radius * 0.44,
                    width: radius * 0.88,
                    height: radius * 0.88
                ),
                transform: nil
            )
            pen.fill(path, color: color)
        }
        let core = CGPath(
            ellipseIn: CGRect(x: center.x - radius * 0.16, y: center.y - radius * 0.16, width: radius * 0.32, height: radius * 0.32),
            transform: nil
        )
        pen.fill(core, color: pen.gold)
    }

    // MARK: - 松竹梅

    private static func pineBambooPlum(_ pen: MotifPen) {
        // 松（左上）・竹（右上）・梅（下）の三角形にまとめる
        pine(pen.child(x: 0.0, y: 0.44, width: 0.54, height: 0.54))
        bamboo(pen.child(x: 0.44, y: 0.42, width: 0.54, height: 0.54))
        plumBranch(pen.child(x: 0.22, y: 0.0, width: 0.56, height: 0.56))
    }

    // MARK: - 富士山

    private static func fuji(_ pen: MotifPen) {
        let rect = pen.box
        // 日の出
        let sun = CGPath(
            ellipseIn: CGRect(
                x: rect.minX + rect.width * 0.64,
                y: rect.minY + rect.height * 0.60,
                width: rect.width * 0.26,
                height: rect.width * 0.26
            ),
            transform: nil
        )
        pen.fill(sun, color: RGBColor(hex: "E0664B").withAlpha(0.9))

        // 山肌
        let mountain = CGMutablePath()
        mountain.move(to: pen.p(0.04, 0.16))
        mountain.addQuadCurve(to: pen.p(0.44, 0.86), control: pen.p(0.2, 0.6))
        mountain.addQuadCurve(to: pen.p(0.96, 0.16), control: pen.p(0.73, 0.5))
        mountain.closeSubpath()
        pen.fill(mountain, color: pen.override ?? pen.palette.primary)

        // 雪化粧
        let snow = CGMutablePath()
        snow.move(to: pen.p(0.3, 0.52))
        snow.addQuadCurve(to: pen.p(0.44, 0.86), control: pen.p(0.37, 0.66))
        snow.addQuadCurve(to: pen.p(0.58, 0.52), control: pen.p(0.51, 0.66))
        // ぎざぎざの雪の縁
        var x = 0.58
        var up = true
        while x > 0.30 {
            let y = up ? 0.56 : 0.5
            snow.addLine(to: pen.p(x - 0.035, y))
            x -= 0.035
            up.toggle()
        }
        snow.closeSubpath()
        pen.fill(snow, color: RGBColor(hex: "FBFBF7"))

        // 麓の霞
        softCloud(pen, from: -0.1, to: 0.52, y: 0.16, thickness: 0.055, color: pen.gold.withAlpha(0.55))
        softCloud(pen, from: 0.42, to: 1.08, y: 0.3, thickness: 0.05, color: pen.gold.withAlpha(0.4))
    }

    // MARK: - 南天

    private static func nandina(_ pen: MotifPen) {
        let stem = CGMutablePath()
        stem.move(to: pen.p(0.5, 0.06))
        stem.addCurve(to: pen.p(0.4, 0.82), control1: pen.p(0.42, 0.3), control2: pen.p(0.36, 0.6))
        pen.stroke(stem, color: pen.wood, width: pen.lineWidthMM * 1.6)
        let branch = CGMutablePath()
        branch.move(to: pen.p(0.44, 0.5))
        branch.addQuadCurve(to: pen.p(0.72, 0.68), control: pen.p(0.58, 0.54))
        pen.stroke(branch, color: pen.wood, width: pen.lineWidthMM * 1.2)

        // 葉
        for (index, leaf) in [(0.22, 0.66), (0.34, 0.86), (0.62, 0.86), (0.78, 0.78), (0.68, 0.5)].enumerated() {
            let angle = Double(index) * 0.7 - 1.0
            let path = CGMutablePath()
            let origin = pen.p(leaf.0, leaf.1)
            let length = pen.l(0.16)
            path.move(to: origin)
            path.addQuadCurve(
                to: CGPoint(x: origin.x + CGFloat(cos(angle)) * length, y: origin.y + CGFloat(sin(angle)) * length * 0.6 + length * 0.2),
                control: CGPoint(x: origin.x + CGFloat(cos(angle)) * length * 0.5, y: origin.y + length * 0.3)
            )
            path.addQuadCurve(to: origin, control: CGPoint(x: origin.x + CGFloat(cos(angle)) * length * 0.5, y: origin.y + length * 0.05))
            pen.fill(path, color: pen.foliage)
        }

        // 実
        let berries: [(Double, Double)] = [
            (0.44, 0.34), (0.54, 0.3), (0.5, 0.42), (0.62, 0.38), (0.38, 0.26), (0.58, 0.22), (0.46, 0.18),
        ]
        for berry in berries {
            pen.circle(center: berry, radius: 0.045, fill: pen.override ?? pen.blossom)
        }
    }

    // MARK: - 水引

    private static func mizuhiki(_ pen: MotifPen) {
        let gold = pen.gold
        let accent = pen.blossom
        for (index, color) in [gold, accent, gold].enumerated() {
            let offset = Double(index - 1) * 0.055
            let path = CGMutablePath()
            path.move(to: pen.p(0.02, 0.5 + offset))
            path.addCurve(
                to: pen.p(0.98, 0.5 + offset),
                control1: pen.p(0.3, 0.62 + offset),
                control2: pen.p(0.7, 0.38 + offset)
            )
            pen.stroke(path, color: color, width: pen.lineWidthMM * 2.2)
        }
        // 中央の結び
        let knot = CGPath(
            ellipseIn: CGRect(
                x: pen.box.midX - pen.l(0.07),
                y: pen.box.midY - pen.l(0.07),
                width: pen.l(0.14),
                height: pen.l(0.14)
            ),
            transform: nil
        )
        pen.fill(knot, color: pen.gold)
        let knotRing = CGPath(
            ellipseIn: CGRect(
                x: pen.box.midX - pen.l(0.07),
                y: pen.box.midY - pen.l(0.07),
                width: pen.l(0.14),
                height: pen.l(0.14)
            ),
            transform: nil
        )
        pen.stroke(knotRing, color: pen.blossom, width: pen.lineWidthMM)
    }

    // MARK: - 扇

    private static func fan(_ pen: MotifPen) {
        let center = pen.p(0.5, 0.06)
        let radius = pen.l(0.86)
        let startAngle = CGFloat(58) * .pi / 180
        let endAngle = CGFloat(122) * .pi / 180
        let sector = CGMutablePath()
        sector.move(to: center)
        sector.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        sector.closeSubpath()
        pen.fill(sector, color: pen.palette.paper)
        // 地紙の縁
        pen.stroke(sector, color: pen.gold, width: pen.lineWidthMM * 1.6)
        // 骨
        for index in 0...6 {
            let t = CGFloat(index) / 6
            let angle = startAngle + (endAngle - startAngle) * t
            let path = CGMutablePath()
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
            pen.stroke(path, color: pen.gold.withAlpha(0.75), width: pen.lineWidthMM * 0.8)
        }
        // 扇形の内側に金雲
        pen.ctx.saveGState()
        pen.ctx.addPath(sector)
        pen.ctx.clip()
        for (index, band) in [(0.42, 0.1), (0.56, 0.08), (0.5, 0.06)].enumerated() {
            let y = band.0
            let width = band.1 + Double(index) * 0.05
            let cloud = CGMutablePath()
            let rect = CGRect(
                x: center.x - radius * CGFloat(width) * 2,
                y: center.y + radius * CGFloat(y),
                width: radius * CGFloat(width) * 4,
                height: radius * 0.05
            )
            cloud.addRoundedRect(in: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2)
            pen.fill(cloud, color: pen.gold.withAlpha(0.55))
        }
        pen.ctx.restoreGState()
        // 要（かなめ）
        let pivot = CGPath(
            ellipseIn: CGRect(x: center.x - pen.l(0.05), y: center.y - pen.l(0.05), width: pen.l(0.1), height: pen.l(0.1)),
            transform: nil
        )
        pen.fill(pivot, color: pen.blossom)
        // 下げ紐
        let cord = CGMutablePath()
        cord.move(to: pen.p(0.5, 0.08))
        cord.addQuadCurve(to: pen.p(0.5, -0.04), control: pen.p(0.56, 0.01))
        pen.stroke(cord, color: pen.blossom, width: pen.lineWidthMM * 1.4)
    }

    // MARK: - 雪輪

    private static func snowRing(_ pen: MotifPen) {
        let center = pen.p(0.5, 0.5)
        let radius = pen.l(0.44)
        let ring = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
        pen.stroke(ring, color: pen.override ?? pen.palette.secondary, width: pen.lineWidthMM * 1.4)
        for index in 0..<6 {
            let angle = CGFloat(index) * .pi / 3
            let path = CGMutablePath()
            path.move(to: center)
            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.96, y: center.y + sin(angle) * radius * 0.96))
            pen.stroke(path, color: pen.override ?? pen.palette.secondary, width: pen.lineWidthMM)
            // 枝
            for side in [-1.0, 1.0] {
                let branchAngle = angle + CGFloat(side) * 0.6
                let startPoint = CGPoint(x: center.x + cos(angle) * radius * 0.6, y: center.y + sin(angle) * radius * 0.6)
                let endPoint = CGPoint(x: startPoint.x + cos(branchAngle) * radius * 0.28, y: startPoint.y + sin(branchAngle) * radius * 0.28)
                let branchPath = CGMutablePath()
                branchPath.move(to: startPoint)
                branchPath.addLine(to: endPoint)
                pen.stroke(branchPath, color: pen.override ?? pen.palette.secondary, width: pen.lineWidthMM * 0.8)
            }
        }
    }

    // MARK: - 門松

    private static func kadomatsu(_ pen: MotifPen) {
        let stalks: [(Double, Double, Double)] = [(0.36, 0.16, 0.72), (0.5, 0.16, 0.9), (0.64, 0.16, 0.78)]
        for (index, stalk) in stalks.enumerated() {
            let (x, bottom, top) = stalk
            let path = CGMutablePath()
            path.move(to: pen.p(x, bottom))
            path.addLine(to: pen.p(x, top))
            pen.stroke(path, color: pen.foliage, width: pen.lineWidthMM * (index == 1 ? 3.0 : 2.4), cap: .butt)
            var y = bottom + 0.09
            while y < top {
                let node = CGMutablePath()
                node.move(to: pen.p(x - 0.035, y))
                node.addLine(to: pen.p(x + 0.035, y))
                pen.stroke(node, color: pen.foliage, width: pen.lineWidthMM)
                y += 0.15
            }
        }
        // 松葉
        pineNeedles(pen, center: (0.34, 0.74), radius: 0.13, angle: -30)
        pineNeedles(pen, center: (0.5, 0.92), radius: 0.14, angle: 0)
        pineNeedles(pen, center: (0.66, 0.8), radius: 0.13, angle: 30)
        // 鉢
        let pot = CGMutablePath()
        pot.move(to: pen.p(0.24, 0.16))
        pot.addLine(to: pen.p(0.76, 0.16))
        pot.addLine(to: pen.p(0.68, 0.03))
        pot.addLine(to: pen.p(0.32, 0.03))
        pot.closeSubpath()
        pen.fillAndStroke(pot, fill: pen.blossom, stroke: pen.gold, width: pen.lineWidthMM * 0.8)
    }

    // MARK: - 干支の漢字

    private static func zodiacKanji(_ pen: MotifPen) {
        let center = pen.p(0.5, 0.5)
        let radius = pen.l(0.45)
        let ring = CGPath(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2), transform: nil)
        pen.stroke(ring, color: pen.override ?? pen.gold, width: pen.lineWidthMM * 1.2)
        let innerRadius = radius * 0.86
        let innerRing = CGPath(
            ellipseIn: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2),
            transform: nil
        )
        pen.stroke(innerRing, color: pen.override ?? pen.gold.withAlpha(0.6), width: pen.lineWidthMM * 0.7)

        let font = FontResolver.font(.mincho, weight: .bold, sizeMM: mm.fromPoints(radius * 1.5))
        pen.text(
            pen.yearInfo.zodiac.kanji,
            font: font,
            color: pen.override ?? pen.palette.ink,
            center: (0.5, 0.5)
        )
        // 小さな金の飾り
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2 + .pi / 4
            let dotCenter = CGPoint(x: center.x + cos(angle) * radius * 1.12, y: center.y + sin(angle) * radius * 1.12)
            let dot = CGPath(
                ellipseIn: CGRect(x: dotCenter.x - pen.l(0.022), y: dotCenter.y - pen.l(0.022), width: pen.l(0.044), height: pen.l(0.044)),
                transform: nil
            )
            pen.fill(dot, color: pen.gold)
        }
    }

    // MARK: - 干支のイラスト（未年・羊）

    private static func sheep(_ pen: MotifPen) {
        let cream = RGBColor(hex: "FFF7EA")
        let outline = pen.override ?? RGBColor(hex: "8C7A63")
        let face = RGBColor(hex: "6B5B4A")
        let accent = pen.blossom

        // 足元の影
        let shadow = CGPath(
            ellipseIn: CGRect(
                x: pen.box.minX + pen.box.width * 0.24,
                y: pen.box.minY + pen.box.height * 0.18,
                width: pen.box.width * 0.56,
                height: pen.box.height * 0.06
            ),
            transform: nil
        )
        pen.fill(shadow, color: RGBColor(hex: "D9CFC0").withAlpha(0.55))

        // 脚
        for x in [0.36, 0.44, 0.56, 0.62] {
            let leg = CGMutablePath()
            leg.move(to: pen.p(x, 0.3))
            leg.addLine(to: pen.p(x + 0.005, 0.21))
            pen.stroke(leg, color: face, width: pen.lineWidthMM * 3.2, cap: .round)
        }

        // 体（もこもこ）
        let fluffPositions: [(Double, Double)] = [
            (0.54, 0.52), (0.42, 0.56), (0.66, 0.56), (0.38, 0.46), (0.7, 0.46),
            (0.46, 0.4), (0.62, 0.4), (0.54, 0.66), (0.4, 0.62), (0.68, 0.62), (0.5, 0.32), (0.6, 0.32),
        ]
        // 輪郭を先に描いてから中を塗ると、重なった輪郭線が消えて
        // もこもこの塊がひとつの形に見える
        for fluff in fluffPositions {
            pen.circle(center: fluff, radius: 0.115, stroke: outline, width: pen.lineWidthMM * 0.9)
        }
        for fluff in fluffPositions {
            pen.circle(center: fluff, radius: 0.115, fill: cream)
        }

        // 頭
        let headCenter = CGPoint(x: pen.box.minX + pen.box.width * 0.28, y: pen.box.minY + pen.box.height * 0.56)
        let headRadiusX = pen.l(0.115)
        let headRadiusY = pen.l(0.1)
        let head = CGPath(
            ellipseIn: CGRect(
                x: headCenter.x - headRadiusX,
                y: headCenter.y - headRadiusY,
                width: headRadiusX * 2,
                height: headRadiusY * 2
            ),
            transform: nil
        )
        pen.fillAndStroke(head, fill: face, stroke: outline, width: pen.lineWidthMM * 0.5)

        // 耳
        for direction in [-1.0, 1.0] {
            let ear = CGMutablePath()
            let base = CGPoint(x: headCenter.x + CGFloat(direction) * headRadiusX * 0.85, y: headCenter.y + headRadiusY * 0.2)
            ear.move(to: base)
            ear.addQuadCurve(
                to: CGPoint(x: base.x + CGFloat(direction) * pen.l(0.09), y: base.y + pen.l(0.045)),
                control: CGPoint(x: base.x + CGFloat(direction) * pen.l(0.04), y: base.y + pen.l(0.07))
            )
            ear.addQuadCurve(
                to: base,
                control: CGPoint(x: base.x + CGFloat(direction) * pen.l(0.04), y: base.y - pen.l(0.02))
            )
            pen.fill(ear, color: face)
        }

        // 目と鼻
        for direction in [-1.0, 1.0] {
            let eye = CGPath(
                ellipseIn: CGRect(
                    x: headCenter.x + CGFloat(direction) * pen.l(0.042) - pen.l(0.013),
                    y: headCenter.y + pen.l(0.012) - pen.l(0.013),
                    width: pen.l(0.026),
                    height: pen.l(0.026)
                ),
                transform: nil
            )
            pen.fill(eye, color: cream)
        }
        let nose = CGPath(
            ellipseIn: CGRect(
                x: headCenter.x - pen.l(0.016),
                y: headCenter.y - pen.l(0.055),
                width: pen.l(0.032),
                height: pen.l(0.024)
            ),
            transform: nil
        )
        pen.fill(nose, color: cream.withAlpha(0.85))

        // 前垂れ（毛）
        let bang = CGMutablePath()
        bang.move(to: CGPoint(x: headCenter.x - headRadiusX * 0.6, y: headCenter.y + headRadiusY * 0.75))
        bang.addQuadCurve(
            to: CGPoint(x: headCenter.x + headRadiusX * 0.6, y: headCenter.y + headRadiusY * 0.75),
            control: CGPoint(x: headCenter.x, y: headCenter.y + headRadiusY * 1.5)
        )
        pen.stroke(bang, color: cream, width: pen.lineWidthMM * 3.2, cap: .round)

        // 首元のリボン
        let ribbonCenter = CGPoint(x: headCenter.x + headRadiusX * 0.9, y: headCenter.y - headRadiusY * 0.35)
        for direction in [-1.0, 1.0] {
            let loop = CGMutablePath()
            loop.move(to: ribbonCenter)
            loop.addQuadCurve(
                to: CGPoint(x: ribbonCenter.x + CGFloat(direction) * pen.l(0.075), y: ribbonCenter.y + pen.l(0.05)),
                control: CGPoint(x: ribbonCenter.x + CGFloat(direction) * pen.l(0.05), y: ribbonCenter.y - pen.l(0.03))
            )
            loop.addQuadCurve(
                to: ribbonCenter,
                control: CGPoint(x: ribbonCenter.x + CGFloat(direction) * pen.l(0.045), y: ribbonCenter.y + pen.l(0.02))
            )
            pen.fill(loop, color: accent)
        }

        // しっぽ（体の右でくるんと巻く）
        let tail = CGMutablePath()
        tail.move(to: pen.p(0.74, 0.56))
        tail.addQuadCurve(to: pen.p(0.8, 0.66), control: pen.p(0.83, 0.56))
        pen.stroke(tail, color: cream, width: pen.lineWidthMM * 3.4, cap: .round)
        pen.stroke(tail, color: outline, width: pen.lineWidthMM * 0.5, cap: .round)

    }
}
