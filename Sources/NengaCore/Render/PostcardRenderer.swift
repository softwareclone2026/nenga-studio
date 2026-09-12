import CoreGraphics
import CoreText
import Foundation

/// 印刷するときと画面で見るときの違いを吸収する。
public enum RenderMode: Sendable {
    /// 印刷・PDF 出力。用紙やガイドは描かない。
    case print
    /// 画面表示。用紙の色、ガイド、写真のプレースホルダを描く。
    case preview
}

/// はがき 1 面を描くレンダラ。座標はすべて mm、カード左下原点（y は上向き）。
public struct PostcardRenderer {
    public var document: NengaDocument
    public var mode: RenderMode
    /// 文面の画像（assets 内のファイル名 → CGImage）を解決する。
    public var assetLoader: ((String) -> CGImage?)?

    public init(
        document: NengaDocument,
        mode: RenderMode = .preview,
        assetLoader: ((String) -> CGImage?)? = nil
    ) {
        self.document = document
        self.mode = mode
        self.assetLoader = assetLoader
    }

    private var card: CGSize {
        CGSize(width: document.paper.widthMM, height: document.paper.heightMM)
    }

    private var yearInfo: YearInfo { document.yearInfo }

    // MARK: - 座標ヘルパー

    /// カード左上原点（y は下向き）の mm 矩形を Core Graphics 座標へ変換する。
    private func cg(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(
            x: mm.pt(x + document.addressLayout.offsetXMM),
            y: mm.pt(Double(card.height) - y - h + document.addressLayout.offsetYMM),
            width: mm.pt(w),
            height: mm.pt(h)
        )
    }

    private func cgRect(_ rect: CGRect) -> CGRect {
        cg(Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))
    }

    private func shifted(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX + document.addressLayout.offsetXMM,
            y: rect.minY + document.addressLayout.offsetYMM,
            width: rect.width,
            height: rect.height
        )
    }

    // MARK: - 宛名面（表面）

    public func drawAddressSurface(_ contact: Contact, context ctx: CGContext) {
        let layout = document.addressLayout
        let paper = document.paper

        if mode == .preview {
            ctx.saveGState()
            ctx.setFillColor(RGBColor(hex: "FFFFFF").cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: mm.pt(Double(card.width)), height: mm.pt(Double(card.height))))
            ctx.restoreGState()
        }

        drawPostalCodeFrame(contact.postalCode, layout: layout, context: ctx)

        let safeBottom = layout.sender.isEnabled ? Double(card.height) - layout.sender.marginMM - 2 : Double(card.height)
        let usableBottom = paper.kind == .plain ? safeBottom : min(safeBottom, Double(card.height) - 12)
        let addressTop = layout.postalCodeFrame.topMM + layout.postalCodeFrame.boxHeightMM + 6.5

        let content = AddressSurfaceContent(contact: contact, layout: layout)

        switch layout.direction {
        case .vertical:
            drawVerticalRecipient(content, top: addressTop, bottom: usableBottom, context: ctx)
        case .horizontal:
            drawHorizontalRecipient(content, top: addressTop, bottom: usableBottom, context: ctx)
        }

        if layout.sender.isEnabled, !document.sender.isEmpty {
            drawSender(context: ctx)
        }

        if mode == .preview, layout.showsGuides {
            drawGuides(context: ctx)
        }
    }

    /// 宛名面に流し込む文字のまとまり。
    private struct AddressSurfaceContent {
        var addressParagraph: String
        var nameParagraph: String
        var coRecipientParagraphs: [String]

        init(contact: Contact, layout: AddressLayout) {
            var addressParts: [String] = []
            if layout.showCompany {
                var company = contact.company
                if !contact.department.isEmpty {
                    company += company.isEmpty ? contact.department : "　\(contact.department)"
                }
                if !company.isEmpty { addressParts.append(company) }
            }
            let address1 = layout.omitPrefecture
                ? AddressFormatter.removingPrefecture(from: contact.address1)
                : contact.address1
            var address2 = contact.address2
            if layout.convertChomeBanchi {
                address2 = AddressFormatter.expandChomeBanchi(address2)
            }
            let address = address1 + address2
            if !address.isEmpty { addressParts.append(address) }
            self.addressParagraph = addressParts.joined(separator: "\n")

            let honorific: String = layout.honorificPlacement == .none ? "" : contact.honorific.rawValue
            var name = contact.fullName + honorific
            let recipients = contact.coRecipients.filter { !$0.name.isEmpty }
            var columns: [String] = []

            switch layout.coRecipientLayout {
            case .sameLine:
                if !recipients.isEmpty {
                    let names = recipients.map { $0.name + (layout.honorificPlacement == .none ? "" : $0.honorific.rawValue) }
                    switch layout.honorificPlacement {
                    case .lastOnly:
                        name = contact.fullName + "・" + names.joined(separator: "・") + honorific
                    case .each, .none:
                        name = contact.fullName + honorific + "・" + names.joined(separator: "・")
                    }
                }
            case .newColumn:
                switch layout.honorificPlacement {
                case .lastOnly:
                    if !recipients.isEmpty { name = contact.fullName }
                    columns = recipients.map(\.name)
                case .each, .none:
                    columns = recipients.map {
                        $0.name + (layout.honorificPlacement == .none ? "" : $0.honorific.rawValue)
                    }
                }
            }
            self.nameParagraph = name
            self.coRecipientParagraphs = columns
        }
    }

    private func drawVerticalRecipient(
        _ content: AddressSurfaceContent,
        top: Double,
        bottom: Double,
        context ctx: CGContext
    ) {
        let layout = document.addressLayout
        let height = max(bottom - top, 20)
        let rightMargin = 14.0
        var right = Double(card.width) - rightMargin

        if !content.addressParagraph.isEmpty {
            let options = TextLayoutOptions(
                font: layout.addressFont,
                sizeMM: layout.addressSizeMM,
                color: .black,
                direction: .vertical,
                alignment: .leading,
                letterSpacingMM: layout.addressSizeMM * 0.04,
                lineSpacingMM: layout.addressSizeMM * 0.55
            )
            let size = TextEngine.measure(content.addressParagraph, options: options, maxHeightMM: height)
            let blockWidth = min(Double(size.width), Double(card.width) * 0.55)
            TextEngine.draw(
                content.addressParagraph,
                options: options,
                in: CGRect(x: right - blockWidth, y: top, width: blockWidth, height: height),
                cardHeightMM: Double(card.height),
                context: ctx
            )
            right -= blockWidth + layout.addressSizeMM * 1.8
        }

        let nameTop = max(top + 8, Double(card.height) * 0.40)
        let nameAvailable = Double(card.height) - nameTop - layout.sender.marginMM
        let nameOptions = TextLayoutOptions(
            font: layout.nameFont,
            sizeMM: layout.nameSizeMM,
            color: .black,
            direction: .vertical,
            alignment: .leading,
            letterSpacingMM: layout.nameSizeMM * 0.06,
            lineSpacingMM: layout.nameSizeMM * 0.8
        )
        let nameSize = TextEngine.measure(content.nameParagraph, options: nameOptions, maxHeightMM: nameAvailable)
        let nameWidth = Double(nameSize.width)
        TextEngine.draw(
            content.nameParagraph,
            options: nameOptions,
            in: CGRect(x: right - nameWidth, y: nameTop, width: nameWidth, height: nameAvailable),
            cardHeightMM: Double(card.height),
            context: ctx
        )
        right -= nameWidth + layout.nameSizeMM * 1.2

        let coSize = layout.nameSizeMM * layout.coRecipientScale
        let coOptions = TextLayoutOptions(
            font: layout.nameFont,
            sizeMM: coSize,
            color: .black,
            direction: .vertical,
            alignment: .leading,
            letterSpacingMM: coSize * 0.05,
            lineSpacingMM: coSize * 0.9
        )
        for paragraph in content.coRecipientParagraphs {
            let size = TextEngine.measure(paragraph, options: coOptions, maxHeightMM: nameAvailable)
            let width = Double(size.width)
            TextEngine.draw(
                paragraph,
                options: coOptions,
                in: CGRect(x: right - width, y: nameTop + coSize * 0.6, width: width, height: nameAvailable),
                cardHeightMM: Double(card.height),
                context: ctx
            )
            right -= width + coSize
        }
    }

    private func drawHorizontalRecipient(
        _ content: AddressSurfaceContent,
        top: Double,
        bottom: Double,
        context ctx: CGContext
    ) {
        let layout = document.addressLayout
        let margin = 16.0
        let width = Double(card.width) - margin * 2
        var y = top

        func drawBlock(_ text: String, options: TextLayoutOptions, spacingAfter: Double) {
            guard !text.isEmpty else { return }
            let size = TextEngine.measure(text, options: options, maxWidthMM: width)
            let height = Double(size.height) + 1.5
            guard y + height <= bottom else { return }
            TextEngine.draw(
                text,
                options: options,
                in: CGRect(x: margin, y: y, width: width, height: height),
                cardHeightMM: Double(card.height),
                context: ctx
            )
            y += height + spacingAfter
        }

        drawBlock(
            content.addressParagraph,
            options: TextLayoutOptions(
                font: layout.addressFont,
                sizeMM: layout.addressSizeMM,
                color: .black,
                direction: .horizontal,
                alignment: .center,
                letterSpacingMM: layout.addressSizeMM * 0.06,
                lineSpacingMM: layout.addressSizeMM * 0.7
            ),
            spacingAfter: 3.0
        )
        drawBlock(
            content.nameParagraph,
            options: TextLayoutOptions(
                font: layout.nameFont,
                sizeMM: layout.nameSizeMM,
                color: .black,
                direction: .horizontal,
                alignment: .center,
                letterSpacingMM: layout.nameSizeMM * 0.12,
                lineSpacingMM: layout.nameSizeMM * 0.4
            ),
            spacingAfter: 1.5
        )
        let coSize = layout.nameSizeMM * layout.coRecipientScale
        for paragraph in content.coRecipientParagraphs {
            drawBlock(
                paragraph,
                options: TextLayoutOptions(
                    font: layout.nameFont,
                    sizeMM: coSize,
                    color: .black,
                    direction: .horizontal,
                    alignment: .center,
                    letterSpacingMM: coSize * 0.1,
                    lineSpacingMM: coSize * 0.3
                ),
                spacingAfter: 1.0
            )
        }
    }

    // MARK: - 郵便番号

    private func drawPostalCodeFrame(_ code: String, layout: AddressLayout, context ctx: CGContext) {
        let spec = layout.postalCodeFrame
        guard spec.showsFrame || spec.showsDigits else { return }
        if spec.showsFrame {
            ctx.saveGState()
            ctx.setStrokeColor(RGBColor(hex: "C1272D").cgColor)
            ctx.setLineWidth(mm.pt(spec.lineWidthMM))
            let frame = cgRect(spec.frameRect())
            ctx.stroke(frame)
            for index in 1..<spec.boxCount {
                let box = cgRect(spec.boxRect(index: index))
                ctx.move(to: CGPoint(x: box.minX, y: frame.minY))
                ctx.addLine(to: CGPoint(x: box.minX, y: frame.maxY))
            }
            ctx.strokePath()
            ctx.restoreGState()
        }
        guard spec.showsDigits else { return }
        let digits = spec.digitPositions(for: code)
        let options = TextLayoutOptions(
            font: .kaku,
            weight: .regular,
            sizeMM: spec.digitSizeMM,
            color: .black,
            direction: .horizontal,
            alignment: .center,
            letterSpacingMM: 0,
            lineSpacingMM: 0
        )
        for digit in digits where !digit.character.isEmpty {
            TextEngine.draw(
                digit.character,
                options: options,
                in: digit.rect,
                cardHeightMM: Double(card.height),
                context: ctx
            )
        }
    }

    // MARK: - 差出人

    private func drawSender(context ctx: CGContext) {
        let layout = document.addressLayout.sender
        let sender = document.sender
        var lines: [String] = []
        if layout.showsPostalCode, !sender.postalCode.isEmpty {
            if layout.direction == .vertical {
                lines.append(sender.postalCode)
            } else {
                lines.append("〒" + AddressFormatter.formattedPostalCode(sender.postalCode))
            }
        }
        var senderAddress2 = sender.address2
        if document.addressLayout.convertChomeBanchi {
            senderAddress2 = AddressFormatter.expandChomeBanchi(senderAddress2)
        }
        let address = sender.address1 + senderAddress2
        if !address.isEmpty { lines.append(address) }
        if !sender.fullName.isEmpty { lines.append(sender.fullName) }
        if layout.showsPhone, !sender.phone.isEmpty { lines.append("TEL \(sender.phone)") }
        if layout.showsEmail, !sender.email.isEmpty { lines.append(sender.email) }
        guard !lines.isEmpty else { return }
        let text = lines.joined(separator: "\n")

        let options = TextLayoutOptions(
            font: .mincho,
            sizeMM: layout.sizeMM,
            color: .black,
            direction: layout.direction,
            alignment: .trailing,
            letterSpacingMM: 0,
            lineSpacingMM: layout.sizeMM * 0.5
        )
        let margin = layout.marginMM
        let maxWidth = Double(card.width) * 0.6
        let maxHeight = Double(card.height) * 0.42
        let size = TextEngine.measure(text, options: options, maxWidthMM: maxWidth, maxHeightMM: maxHeight)
        let width = min(max(Double(size.width), 12), maxWidth)
        let height = min(max(Double(size.height), 8), maxHeight)
        let x = layout.corner == .bottomLeft
            ? margin
            : Double(card.width) - margin - width
        let y = Double(card.height) - margin - height
        TextEngine.draw(
            text,
            options: options,
            in: CGRect(x: x, y: y, width: width, height: height),
            cardHeightMM: Double(card.height),
            context: ctx
        )
    }

    // MARK: - ガイド（画面表示のみ）

    private func drawGuides(context ctx: CGContext) {
        ctx.saveGState()
        ctx.setLineWidth(mm.pt(0.2))
        ctx.setStrokeColor(RGBColor(hex: "3A7BD5").withAlpha(0.35).cgColor)
        ctx.setLineDash(phase: 0, lengths: [mm.pt(1.2), mm.pt(1.2)])
        if document.paper.kind != .plain {
            ctx.stroke(cg(0, Double(card.height) - 12, Double(card.width), 12))
        }
        if document.addressLayout.sender.isEnabled {
            ctx.stroke(cg(0, Double(card.height) - 42, Double(card.width) * 0.45, 42))
        }
        ctx.restoreGState()
    }

    // MARK: - 文面（裏面）

    public func drawDesignSurface(contact: Contact?, context ctx: CGContext) {
        let page = document.design
        if mode == .preview {
            ctx.saveGState()
            ctx.setFillColor(page.paperColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: mm.pt(Double(card.width)), height: mm.pt(Double(card.height))))
            ctx.restoreGState()
        }
        // はがきの外へはみ出した絵柄は印刷しない（プリンタ内を汚さないため）
        ctx.saveGState()
        ctx.clip(
            to: CGRect(
                x: mm.pt(document.addressLayout.offsetXMM),
                y: mm.pt(document.addressLayout.offsetYMM),
                width: mm.pt(Double(card.width)),
                height: mm.pt(Double(card.height))
            )
        )
        for element in page.elements {
            draw(element: element, contact: contact, context: ctx)
        }
        ctx.restoreGState()
        if mode == .preview, document.addressLayout.showsGuides, document.paper.kind != .plain {
            ctx.saveGState()
            ctx.setLineWidth(mm.pt(0.2))
            ctx.setStrokeColor(RGBColor(hex: "3A7BD5").withAlpha(0.35).cgColor)
            ctx.setLineDash(phase: 0, lengths: [mm.pt(1.2), mm.pt(1.2)])
            ctx.stroke(cg(0, Double(card.height) - 10, Double(card.width), 10))
            ctx.restoreGState()
        }
    }

    private func draw(element: DesignElement, contact: Contact?, context ctx: CGContext) {
        let frame = element.frame
        ctx.saveGState()
        ctx.setAlpha(CGFloat(element.opacity))
        if frame.rotationDegrees != 0 {
            let cgCenter = CGPoint(
                x: mm.pt(frame.centerX + document.addressLayout.offsetXMM),
                y: mm.pt(Double(card.height) - frame.centerY + document.addressLayout.offsetYMM)
            )
            ctx.translateBy(x: cgCenter.x, y: cgCenter.y)
            ctx.rotate(by: CGFloat(frame.rotationDegrees) * .pi / 180)
            ctx.translateBy(x: -cgCenter.x, y: -cgCenter.y)
        }
        switch element {
        case .text(let text):
            drawTextElement(text, contact: contact, context: ctx)
        case .shape(let shape):
            drawShapeElement(shape, context: ctx)
        case .motif(let motif):
            drawMotifElement(motif, context: ctx)
        case .image(let image):
            drawImageElement(image, context: ctx)
        }
        ctx.restoreGState()
    }

    private func drawTextElement(_ element: TextElement, contact: Contact?, context ctx: CGContext) {
        let raw = element.usesPlaceholders
            ? Placeholder.expand(element.text, contact: contact, yearInfo: yearInfo)
            : element.text
        let options = TextLayoutOptions(
            font: element.font,
            weight: element.weight,
            sizeMM: element.sizeMM,
            color: element.color,
            direction: element.direction,
            alignment: element.alignment,
            letterSpacingMM: element.letterSpacingMM,
            lineSpacingMM: element.lineSpacingMM
        )
        TextEngine.draw(
            raw,
            options: options,
            in: shifted(CGRect(x: element.frame.x, y: element.frame.y, width: element.frame.width, height: element.frame.height)),
            cardHeightMM: Double(card.height),
            context: ctx
        )
    }

    private func drawShapeElement(_ element: ShapeElement, context ctx: CGContext) {
        let rect = cgRect(shifted(CGRect(x: element.frame.x, y: element.frame.y, width: element.frame.width, height: element.frame.height)))
        let path: CGPath
        switch element.kind {
        case .rectangle:
            path = CGPath(rect: rect, transform: nil)
        case .roundedRectangle:
            path = CGPath(
                roundedRect: rect,
                cornerWidth: mm.pt(element.cornerRadiusMM),
                cornerHeight: mm.pt(element.cornerRadiusMM),
                transform: nil
            )
        case .ellipse:
            path = CGPath(ellipseIn: rect, transform: nil)
        case .line, .dashedLine:
            let line = CGMutablePath()
            line.move(to: CGPoint(x: rect.minX, y: rect.midY))
            line.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path = line
        }
        if let fill = element.fill {
            ctx.saveGState()
            ctx.setFillColor(fill.cgColor)
            ctx.addPath(path)
            ctx.fillPath()
            ctx.restoreGState()
        }
        if let stroke = element.stroke {
            ctx.saveGState()
            ctx.setStrokeColor(stroke.cgColor)
            ctx.setLineWidth(mm.pt(element.strokeWidthMM))
            if element.kind == .dashedLine {
                ctx.setLineDash(phase: 0, lengths: [mm.pt(1.5), mm.pt(1.5)])
            }
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private func drawMotifElement(_ element: MotifElement, context ctx: CGContext) {
        let rect = cgRect(shifted(CGRect(x: element.frame.x, y: element.frame.y, width: element.frame.width, height: element.frame.height)))
        let motifContext = MotifContext(
            rect: rect,
            palette: element.palette,
            lineWidthMM: element.lineWidthMM,
            overrideColor: element.overrideColor,
            yearInfo: yearInfo
        )
        MotifRenderer.draw(element.kind, context: motifContext, in: ctx)
    }

    private func drawImageElement(_ element: ImageElement, context ctx: CGContext) {
        let rect = cgRect(shifted(CGRect(x: element.frame.x, y: element.frame.y, width: element.frame.width, height: element.frame.height)))
        let fileName = element.assetFileName
        if !fileName.isEmpty, let image = assetLoader?(fileName) {
            ctx.saveGState()
            if element.cornerRadiusMM > 0 {
                let clip = CGPath(
                    roundedRect: rect,
                    cornerWidth: mm.pt(element.cornerRadiusMM),
                    cornerHeight: mm.pt(element.cornerRadiusMM),
                    transform: nil
                )
                ctx.addPath(clip)
                ctx.clip()
            }
            let imageSize = CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
            let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            ctx.draw(
                image,
                in: CGRect(
                    x: rect.midX - drawSize.width / 2,
                    y: rect.midY - drawSize.height / 2,
                    width: drawSize.width,
                    height: drawSize.height
                )
            )
            ctx.restoreGState()
        } else if mode == .preview {
            ctx.saveGState()
            ctx.setFillColor(RGBColor(hex: "F1F1EC").cgColor)
            ctx.fill(rect)
            ctx.setStrokeColor(RGBColor(hex: "C9C9C2").cgColor)
            ctx.setLineWidth(mm.pt(0.3))
            ctx.stroke(rect)
            let cross = CGMutablePath()
            cross.move(to: CGPoint(x: rect.minX, y: rect.minY))
            cross.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            cross.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            cross.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            ctx.addPath(cross)
            ctx.setStrokeColor(RGBColor(hex: "DCDCD6").cgColor)
            ctx.strokePath()
            ctx.restoreGState()
            let options = TextLayoutOptions(
                font: .kaku,
                sizeMM: min(element.frame.height * 0.28, 8),
                color: RGBColor(hex: "A8A8A0"),
                direction: .horizontal,
                alignment: .center
            )
            TextEngine.draw(
                "写真を配置",
                options: options,
                in: CGRect(x: element.frame.x, y: element.frame.y, width: element.frame.width, height: element.frame.height),
                cardHeightMM: Double(card.height),
                context: ctx
            )
        }
    }

    // MARK: - 位置合わせシート

    /// 郵便番号枠や印刷位置を実機に合わせるためのテストシート。
    public func drawCalibrationSheet(context ctx: CGContext) {
        let width = Double(card.width)
        let height = Double(card.height)
        ctx.saveGState()
        ctx.setFillColor(RGBColor(hex: "FFFFFF").cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: mm.pt(width), height: mm.pt(height)))
        ctx.setLineWidth(mm.pt(0.15))
        ctx.setStrokeColor(RGBColor(hex: "B9C6D8").cgColor)
        var x = 0.0
        while x <= width {
            let line = cg(x, 0, 0, height)
            ctx.move(to: CGPoint(x: line.minX, y: line.minY))
            ctx.addLine(to: CGPoint(x: line.minX, y: line.maxY))
            x += 5
        }
        var y = 0.0
        while y <= height {
            let line = cg(0, y, width, 0)
            ctx.move(to: CGPoint(x: line.minX, y: line.minY))
            ctx.addLine(to: CGPoint(x: line.maxX, y: line.minY))
            y += 5
        }
        ctx.strokePath()

        let spec = document.addressLayout.postalCodeFrame
        ctx.setStrokeColor(RGBColor(hex: "C1272D").cgColor)
        ctx.setLineWidth(mm.pt(0.25))
        let frame = cgRect(spec.frameRect())
        ctx.stroke(frame)
        for index in 1..<spec.boxCount {
            let box = cgRect(spec.boxRect(index: index))
            ctx.move(to: CGPoint(x: box.minX, y: frame.minY))
            ctx.addLine(to: CGPoint(x: box.minX, y: frame.maxY))
        }
        ctx.strokePath()

        ctx.setStrokeColor(RGBColor(hex: "22303F").cgColor)
        ctx.setLineWidth(mm.pt(0.3))
        let tick = 6.0
        for corner in [(0.0, 0.0), (width, 0.0), (0.0, height), (width, height)] {
            let cx = corner.0
            let cy = corner.1
            let horizontal = cg(cx == 0 ? 0 : cx - tick, cy == 0 ? 0 : cy - 0.15, tick, 0.3)
            ctx.addPath(CGPath(rect: horizontal, transform: nil))
            let vertical = cg(cx == 0 ? 0 : cx - 0.15, cy == 0 ? 0 : cy - tick, 0.3, tick)
            ctx.addPath(CGPath(rect: vertical, transform: nil))
        }
        ctx.fillPath()

        let options = TextLayoutOptions(
            font: .kaku,
            sizeMM: 2.6,
            color: RGBColor(hex: "22303F"),
            direction: .horizontal,
            alignment: .center
        )
        TextEngine.draw(
            "位置合わせシート（5mm 方眼） 郵便番号枠の基準位置: 左 \(Int(spec.leftMM))mm / 上 \(Int(spec.topMM))mm",
            options: options,
            in: CGRect(x: 10, y: height - 12, width: width - 20, height: 5),
            cardHeightMM: height,
            context: ctx
        )
        ctx.restoreGState()
    }
}
