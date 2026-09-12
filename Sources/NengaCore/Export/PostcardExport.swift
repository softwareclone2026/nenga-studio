import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 印刷・PDF に載せる 1 ページ。
public enum PostcardPage: Sendable {
    case address(Contact)
    case design(contact: Contact?)
    case calibration
}

/// はがきの PDF / 画像出力。用紙の向き（回転）もここで面倒を見る。
public enum PostcardExport {
    public static func pageSizeMM(_ document: NengaDocument) -> CGSize {
        let card = CGSize(width: document.paper.widthMM, height: document.paper.heightMM)
        switch document.printRotation {
        case .clockwise, .counterClockwise:
            return CGSize(width: card.height, height: card.width)
        case .none, .upsideDown:
            return card
        }
    }

    public static func pageSizePoints(_ document: NengaDocument) -> CGSize {
        let size = pageSizeMM(document)
        return CGSize(width: mm.pt(Double(size.width)), height: mm.pt(Double(size.height)))
    }

    /// カード座標（左下原点・mm）から用紙座標への変換をかける。
    /// レンダラは描画時に mm→pt を済ませているため、ここでは回転と平行移動だけを行う。
    private static func applyPaperTransform(
        _ document: NengaDocument,
        context ctx: CGContext,
        pageSize: CGSize
    ) {
        let card = CGSize(width: document.paper.widthMM, height: document.paper.heightMM)
        switch document.printRotation {
        case .none:
            ctx.translateBy(x: 0, y: 0)
        case .clockwise:
            // (x, y) → (y, pageH - x)
            ctx.translateBy(x: 0, y: mm.pt(Double(pageSize.height)))
            ctx.rotate(by: -CGFloat.pi / 2)
        case .upsideDown:
            ctx.translateBy(x: mm.pt(Double(pageSize.width)), y: mm.pt(Double(pageSize.height)))
            ctx.rotate(by: .pi)
        case .counterClockwise:
            ctx.translateBy(x: mm.pt(Double(card.height)), y: 0)
            ctx.rotate(by: .pi / 2)
        }
    }

    // MARK: - PDF

    public static func makePDF(
        document: NengaDocument,
        pages: [PostcardPage],
        mode: RenderMode = .print,
        assetLoader: ((String) -> CGImage?)? = nil
    ) throws -> Data {
        let pageSize = pageSizeMM(document)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            throw ExportError.cannotCreateContext
        }
        var mediaBox = CGRect(
            x: 0,
            y: 0,
            width: mm.pt(Double(pageSize.width)),
            height: mm.pt(Double(pageSize.height))
        )
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.cannotCreateContext
        }
        let renderer = PostcardRenderer(document: document, mode: mode, assetLoader: assetLoader)

        for page in pages {
            ctx.beginPDFPage(nil)
            // PDF の原点は左下。mm 座標に合わせて拡大し、必要なら回転する。
            ctx.saveGState()
            ctx.translateBy(x: 0, y: 0)
            applyPaperTransform(document, context: ctx, pageSize: pageSize)
            switch page {
            case .address(let contact):
                renderer.drawAddressSurface(contact, context: ctx)
            case .design(let contact):
                renderer.drawDesignSurface(contact: contact, context: ctx)
            case .calibration:
                renderer.drawCalibrationSheet(context: ctx)
            }
            ctx.restoreGState()
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    public static func writePDF(
        document: NengaDocument,
        pages: [PostcardPage],
        to url: URL,
        mode: RenderMode = .print,
        assetLoader: ((String) -> CGImage?)? = nil
    ) throws {
        let data = try makePDF(document: document, pages: pages, mode: mode, assetLoader: assetLoader)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - 画像（PNG）

    /// プレビューやサムネイル用にカード 1 面を PNG にする。
    public static func makePNG(
        document: NengaDocument,
        page: PostcardPage,
        dpi: Double = 200,
        assetLoader: ((String) -> CGImage?)? = nil
    ) throws -> Data {
        let card = CGSize(width: document.paper.widthMM, height: document.paper.heightMM)
        let pixelWidth = Int(Double(card.width) / 25.4 * dpi)
        let pixelHeight = Int(Double(card.height) / 25.4 * dpi)
        guard pixelWidth > 0, pixelHeight > 0 else { throw ExportError.cannotCreateContext }
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ExportError.cannotCreateContext
        }
        ctx.setFillColor(RGBColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        let scale = CGFloat(pixelWidth) / mm.pt(Double(card.width))
        ctx.scaleBy(x: scale, y: scale)

        let renderer = PostcardRenderer(document: document, mode: .preview, assetLoader: assetLoader)
        switch page {
        case .address(let contact):
            renderer.drawAddressSurface(contact, context: ctx)
        case .design(let contact):
            renderer.drawDesignSurface(contact: contact, context: ctx)
        case .calibration:
            renderer.drawCalibrationSheet(context: ctx)
        }
        guard let image = ctx.makeImage() else { throw ExportError.cannotCreateContext }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw ExportError.cannotEncodeImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.cannotEncodeImage }
        return output as Data
    }

    public enum ExportError: Error, LocalizedError {
        case cannotCreateContext
        case cannotEncodeImage

        public var errorDescription: String? {
            switch self {
            case .cannotCreateContext: "描画用のコンテキストを作成できませんでした。"
            case .cannotEncodeImage: "画像の書き出しに失敗しました。"
            }
        }
    }
}
