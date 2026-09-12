import AppKit
import NengaCore
import PDFKit
import SwiftUI

/// 見出し付きの枠。インスペクタの区切りに使う。
struct PanelSection<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

/// ラベル付きの数値入力（mm）。
struct MillimeterField: View {
    var label: String
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...200
    var step: Double = 0.5
    var suffix: String = "mm"

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 96, alignment: .leading)
            TextField("", value: $value, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
            Text(suffix)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

struct LabeledTextField: View {
    var label: String
    @Binding var text: String
    var prompt: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .frame(width: 96, alignment: .leading)
            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
        }
        .font(.callout)
    }
}

/// SwiftUI の ColorPicker とモデルの色（NengaCore.RGBColor）をつなぐ。
struct ColorPickerRow: View {
    var label: String
    @Binding var color: NengaCore.RGBColor

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 96, alignment: .leading)
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(red: Double(color.r) / 255, green: Double(color.g) / 255, blue: Double(color.b) / 255, opacity: color.a) },
                    set: { newValue in
                        let resolved = NSColor(newValue).usingColorSpace(.sRGB) ?? .black
                        color = NengaCore.RGBColor(
                            r: UInt8(max(0, min(255, resolved.redComponent * 255))),
                            g: UInt8(max(0, min(255, resolved.greenComponent * 255))),
                            b: UInt8(max(0, min(255, resolved.blueComponent * 255))),
                            a: Double(resolved.alphaComponent)
                        )
                    }
                ),
                supportsOpacity: true
            )
            .labelsHidden()
            Text(color.hexString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

/// PDFKit のビュー。宛名面のプレビューに使う。
struct PDFPreviewView: NSViewRepresentable {
    var data: Data
    var pageIndex: Int
    var autoScales: Bool = true

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = autoScales
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.backgroundColor = NSColor.windowBackgroundColor
        view.document = PDFDocument(data: data)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        if view.document?.dataRepresentation() != data {
            view.document = PDFDocument(data: data)
        }
        if let document = view.document, document.pageCount > pageIndex,
           let page = document.page(at: pageIndex) {
            view.go(to: page)
        }
    }
}

/// カード 1 面のプレビュー。レンダラの出力をそのまま表示する。
struct PostcardPreviewImage: View {
    var document: NengaDocument
    var page: PostcardPage
    var assetLoader: ((String) -> CGImage?)?
    var dpi: Double = 190
    @State private var image: CGImage?

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(CGFloat(document.paper.widthMM / document.paper.heightMM), contentMode: .fit)
                    .overlay(
                        Rectangle().stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .aspectRatio(CGFloat(document.paper.widthMM / document.paper.heightMM), contentMode: .fit)
            }
        }
        .onAppear(perform: render)
        .onChange(of: renderKey) { _, _ in render() }
    }

    /// 再描画が必要かどうかの判定に使う軽いキー。
    private var renderKey: String {
        let design = document.design.elements.map { "\($0.id)-\($0.frame)-\($0.opacity)" }.joined()
        let layout = "\(document.addressLayout)"
        let paper = "\(document.paper)"
        let pageKey: String
        switch page {
        case .address(let contact): pageKey = "address-\(contact)"
        case .design: pageKey = "design"
        case .calibration: pageKey = "calibration"
        }
        return design + layout + paper + pageKey
    }

    private func render() {
        image = PostcardExport.makeCGImage(
            document: document,
            page: page,
            dpi: dpi,
            assetLoader: assetLoader
        )
    }
}

extension PostcardExport {
    /// 画面表示用の CGImage。PNG を経由せずそのまま返す。
    public static func makeCGImage(
        document: NengaDocument,
        page: PostcardPage,
        dpi: Double = 190,
        assetLoader: ((String) -> CGImage?)? = nil
    ) -> CGImage? {
        let card = CGSize(width: document.paper.widthMM, height: document.paper.heightMM)
        let pixelWidth = max(1, Int(Double(card.width) / 25.4 * dpi))
        let pixelHeight = max(1, Int(Double(card.height) / 25.4 * dpi))
        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.setFillColor(NengaCore.RGBColor.white.cgColor)
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
        return ctx.makeImage()
    }
}

/// 添付画像を読み込むためのヘルパー。
enum ImageLoading {
    static func cgImage(from url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NengaProjectDocument.decodeImage(data)
    }
}
