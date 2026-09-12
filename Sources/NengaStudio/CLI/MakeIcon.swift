import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import NengaCore
import UniformTypeIdentifiers

/// アプリアイコンを描き出す。モチーフ描画をそのまま使うのでアプリと絵柄が揃う。
enum MakeIcon {
    static func run(outputPath: String) -> Int32 {
        let size = 1024
        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 1 }

        // 512pt のデザインを 2 倍で描く
        let scale = CGFloat(size) / 512
        ctx.scaleBy(x: scale, y: scale)
        let design = CGRect(x: 0, y: 0, width: 512, height: 512)

        // 背景（生成りの和紙）
        let background = CGPath(
            roundedRect: design.insetBy(dx: 8, dy: 8),
            cornerWidth: 108,
            cornerHeight: 108,
            transform: nil
        )
        ctx.saveGState()
        ctx.addPath(background)
        ctx.clip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [
                NengaCore.RGBColor(hex: "FFFDF6").cgColor,
                NengaCore.RGBColor(hex: "F6E7C8").cgColor,
            ] as CFArray,
            locations: [0, 1]
        )
        if let gradient {
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: design.maxY),
                end: CGPoint(x: 0, y: 0),
                options: []
            )
        }
        ctx.restoreGState()

        // 金雲
        let cloudContext = MotifContext(
            rect: CGRect(x: 20, y: 300, width: 472, height: 190),
            palette: .kohaku,
            lineWidthMM: 1.6,
            yearInfo: YearInfo(year: 2027)
        )
        MotifRenderer.draw(.goldCloud, context: cloudContext, in: ctx)

        // はがき
        ctx.saveGState()
        ctx.translateBy(x: 236, y: 268)
        ctx.rotate(by: -0.07)
        let card = CGRect(x: -168, y: -120, width: 336, height: 240)
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: NengaCore.RGBColor(hex: "6B5B4A").withAlpha(0.3).cgColor)
        ctx.setFillColor(NengaCore.RGBColor.white.cgColor)
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        ctx.setStrokeColor(NengaCore.RGBColor(hex: "E6DCC8").cgColor)
        ctx.setLineWidth(2)
        ctx.addPath(CGPath(roundedRect: card, cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.strokePath()

        // 郵便番号枠
        let boxWidth: CGFloat = 20
        let boxHeight: CGFloat = 26
        let frameOrigin = CGPoint(x: card.minX + 42, y: card.maxY - 52)
        ctx.setStrokeColor(NengaCore.RGBColor(hex: "C1272D").cgColor)
        ctx.setLineWidth(2)
        for index in 0...7 {
            let x = frameOrigin.x + CGFloat(index) * boxWidth
            ctx.move(to: CGPoint(x: x, y: frameOrigin.y))
            ctx.addLine(to: CGPoint(x: x, y: frameOrigin.y + boxHeight))
        }
        ctx.move(to: frameOrigin)
        ctx.addLine(to: CGPoint(x: frameOrigin.x + boxWidth * 7, y: frameOrigin.y))
        ctx.move(to: CGPoint(x: frameOrigin.x, y: frameOrigin.y + boxHeight))
        ctx.addLine(to: CGPoint(x: frameOrigin.x + boxWidth * 7, y: frameOrigin.y + boxHeight))
        ctx.strokePath()

        // 宛名の文字（線で表現）
        ctx.setFillColor(NengaCore.RGBColor(hex: "2A2320").withAlpha(0.75).cgColor)
        for (index, width) in [CGFloat(150), 190, 120].enumerated() {
            let bar = CGRect(
                x: card.minX + 44,
                y: card.maxY - 120 - CGFloat(index) * 34,
                width: width,
                height: 12
            )
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 6, cornerHeight: 6, transform: nil))
        }
        ctx.fillPath()

        // 差出人（右下の小さな線）
        ctx.setFillColor(NengaCore.RGBColor(hex: "2A2320").withAlpha(0.35).cgColor)
        for index in 0..<2 {
            let bar = CGRect(
                x: card.maxX - 120,
                y: card.minY + 30 + CGFloat(index) * 20,
                width: 76,
                height: 8
            )
            ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 4, cornerHeight: 4, transform: nil))
        }
        ctx.fillPath()
        ctx.restoreGState()

        // 朱印
        let sealCenter = CGPoint(x: 372, y: 168)
        let sealRadius: CGFloat = 96
        ctx.setFillColor(NengaCore.RGBColor(hex: "C1272D").cgColor)
        ctx.fillEllipse(in: CGRect(
            x: sealCenter.x - sealRadius,
            y: sealCenter.y - sealRadius,
            width: sealRadius * 2,
            height: sealRadius * 2
        ))
        ctx.setStrokeColor(NengaCore.RGBColor(hex: "FFFDF6").withAlpha(0.55).cgColor)
        ctx.setLineWidth(4)
        ctx.strokeEllipse(in: CGRect(
            x: sealCenter.x - sealRadius + 12,
            y: sealCenter.y - sealRadius + 12,
            width: (sealRadius - 12) * 2,
            height: (sealRadius - 12) * 2
        ))
        drawKanji("賀", in: ctx, center: sealCenter, size: 118, color: NengaCore.RGBColor(hex: "FFFDF6"))

        guard let image = ctx.makeImage() else { return 1 }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return 1 }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return 1 }
        do {
            try (data as Data).write(to: URL(fileURLWithPath: outputPath))
            print("アイコンを出力しました: \(outputPath)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("アイコンの書き出しに失敗: \(error)\n".utf8))
            return 1
        }
    }

    private static func drawKanji(_ text: String, in ctx: CGContext, center: CGPoint, size: CGFloat, color: NengaCore.RGBColor) {
        let font = CTFontCreateWithName("HiraMinProN-W6" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: center.x - width / 2, y: center.y - (ascent - descent) / 2)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }
}
