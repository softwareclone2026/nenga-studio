import AppKit
import CoreText
import NengaCore
import SwiftUI

/// 文面（裏面）の編集画面。
struct DesignPane: View {
    @ObservedObject var document: NengaProjectDocument
    @Binding var selectedElementID: UUID?
    @Binding var previewContactID: UUID?

    @Environment(\.undoManager) private var undoManager

    private var previewContact: Contact? {
        guard let previewContactID else { return document.model.contacts.first }
        return document.model.contacts.first { $0.id == previewContactID } ?? document.model.contacts.first
    }

    var body: some View {
        HSplitView {
            templateColumn
                .frame(minWidth: 200, idealWidth: 230, maxWidth: 300)
            VStack(spacing: 0) {
                canvasToolbar
                Divider()
                CanvasView(
                    document: document,
                    selectedElementID: $selectedElementID,
                    previewContact: previewContact
                )
                .padding(20)
                .background(Color(nsColor: .underPageBackgroundColor))
            }
            .frame(minWidth: 420)
            elementColumn
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        }
    }

    // MARK: - テンプレート

    private var templateColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("テンプレート")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                ForEach(NengaTemplates.categories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(category)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                        ForEach(NengaTemplates.all.filter { $0.category == category }) { template in
                            TemplateRow(
                                template: template,
                                document: document,
                                previewContact: previewContact,
                                isSelected: document.model.design.templateID == template.id
                            ) {
                                apply(template)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func apply(_ template: NengaTemplate) {
        document.update(undoManager: undoManager, actionName: "テンプレートを適用") { model in
            model.design = template.make(model.year)
        }
        selectedElementID = nil
    }

    // MARK: - キャンバスのツールバー

    private var canvasToolbar: some View {
        HStack(spacing: 8) {
            Menu {
                Button("テキストを追加") { addText() }
                Menu("図形を追加") {
                    ForEach(ShapeKind.allCases, id: \.self) { kind in
                        Button(kind.label) { addShape(kind) }
                    }
                }
                Menu("モチーフを追加") {
                    Section("絵柄") {
                        ForEach(MotifKind.drawingMotifs, id: \.self) { kind in
                            Button(kind.label) { addMotif(kind) }
                        }
                    }
                    Section("文様") {
                        ForEach(MotifKind.patternMotifs, id: \.self) { kind in
                            Button(kind.label) { addMotif(kind) }
                        }
                    }
                }
                Menu("賀詞を挿入") {
                    ForEach(NengaGreetings.groups) { group in
                        Section(group.title) {
                            ForEach(group.phrases, id: \.self) { phrase in
                                Button(phrase) { addGreeting(phrase) }
                            }
                        }
                    }
                }
                Button("写真を追加…") { addImage() }
            } label: {
                Label("要素を追加", systemImage: "plus.rectangle.on.rectangle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 140)

            Divider().frame(height: 18)

            Picker("差し込み", selection: $previewContactID) {
                Text("（差し込みなし）").tag(UUID?.none)
                ForEach(document.model.contacts) { contact in
                    Text(contact.displayName).tag(UUID?.some(contact.id))
                }
            }
            .frame(width: 180)
            .help("宛名を差し込む文面の確認相手を選びます。")

            Toggle("ガイド", isOn: Binding(
                get: { document.model.addressLayout.showsGuides },
                set: { newValue in
                    document.update(undoManager: undoManager, actionName: "ガイド表示") { model in
                        model.addressLayout.showsGuides = newValue
                    }
                }
            ))
            .toggleStyle(.checkbox)

            Spacer()

            Button {
                document.update(undoManager: undoManager, actionName: "要素を削除") { model in
                    guard let id = selectedElementID else { return }
                    model.design[id] = nil
                }
                selectedElementID = nil
            } label: {
                Label("削除", systemImage: "trash")
            }
            .disabled(selectedElementID == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - 要素一覧とインスペクタ

    private var elementColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PanelSection("要素", subtitle: "上が手前になります") {
                    ForEach(document.model.design.elements.reversed()) { element in
                        ElementRow(
                            element: element,
                            isSelected: element.id == selectedElementID
                        ) {
                            selectedElementID = element.id
                        }
                    }
                    if document.model.design.elements.isEmpty {
                        Text("要素がありません")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if let id = selectedElementID, document.model.design[id] != nil {
                    ElementInspector(
                        document: document,
                        elementID: id,
                        onDelete: {
                            document.update(undoManager: undoManager, actionName: "要素を削除") { model in
                                model.design[id] = nil
                            }
                            selectedElementID = nil
                        }
                    )
                }
            }
            .padding(12)
        }
    }

    // MARK: - 要素の追加

    private func addText() {
        var element = TextElement(
            frame: ElementFrame(x: 20, y: 20, width: 40, height: 60),
            text: "あけましておめでとうございます",
            sizeMM: 6
        )
        element.name = "テキスト"
        document.update(undoManager: undoManager, actionName: "テキストを追加") { model in
            model.design.elements.append(.text(element))
        }
        selectedElementID = element.id
    }

    private func addShape(_ kind: ShapeKind) {
        let element = ShapeElement(
            frame: ElementFrame(x: 50, y: 35, width: 48, height: 30),
            kind: kind,
            fill: kind == .line || kind == .dashedLine ? nil : NengaCore.RGBColor(hex: "FFFFFF").withAlpha(0.9),
            stroke: NengaCore.RGBColor(hex: "C9A227"),
            strokeWidthMM: 0.5
        )
        document.update(undoManager: undoManager, actionName: "図形を追加") { model in
            model.design.elements.append(.shape(element))
        }
        selectedElementID = element.id
    }

    private func addMotif(_ kind: MotifKind) {
        var paletteName = Palette.kohaku.name
        if let existing = document.model.design.elements.compactMap({ element -> String? in
            if case .motif(let motif) = element { return motif.paletteName }
            return nil
        }).first {
            paletteName = existing
        }
        let element = MotifElement(
            frame: ElementFrame(x: 40, y: 20, width: 60, height: 60),
            kind: kind,
            paletteName: paletteName
        )
        document.update(undoManager: undoManager, actionName: "モチーフを追加") { model in
            model.design.elements.append(.motif(element))
        }
        selectedElementID = element.id
    }

    /// 賀詞や挨拶文を、文面に合った大きさの縦書きテキストとして置く。
    private func addGreeting(_ phrase: String) {
        let isLong = phrase.count > 12
        let size = isLong ? 5.6 : 11.0
        let element = TextElement(
            name: "賀詞（\(phrase.prefix(8))）",
            frame: ElementFrame(x: 96, y: 18, width: 48, height: min(Double(phrase.count) * size + 6, 70)),
            text: phrase,
            font: .mincho,
            weight: isLong ? .regular : .bold,
            sizeMM: size,
            direction: .vertical,
            alignment: .leading,
            letterSpacingMM: isLong ? 0.6 : 1.2,
            lineSpacingMM: isLong ? 3.0 : 2.0
        )
        document.update(undoManager: undoManager, actionName: "賀詞を挿入") { model in
            model.design.elements.append(.text(element))
        }
        selectedElementID = element.id
    }

    private func addImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        let fileName = document.addAsset(data: data, fileName: url.lastPathComponent)
        let element = ImageElement(
            name: url.deletingPathExtension().lastPathComponent,
            frame: ElementFrame(x: 30, y: 20, width: 70, height: 50),
            assetFileName: fileName
        )
        document.update(undoManager: undoManager, actionName: "写真を追加") { model in
            model.design.elements.append(.image(element))
        }
        selectedElementID = element.id
    }
}

private struct TemplateRow: View {
    var template: NengaTemplate
    var document: NengaProjectDocument
    var previewContact: Contact?
    var isSelected: Bool
    var apply: () -> Void

    @State private var thumbnail: CGImage?

    var body: some View {
        Button(action: apply) {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    if let thumbnail {
                        Image(decorative: thumbnail, scale: 1)
                            .resizable()
                            .aspectRatio(1.48, contentMode: .fit)
                    } else {
                        Color(nsColor: .controlBackgroundColor)
                            .aspectRatio(1.48, contentMode: .fit)
                    }
                }
                .frame(width: 74)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(2)
                    Text(template.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .onAppear(perform: render)
    }

    private func render() {
        var copy = document.model
        copy.design = template.make(copy.year)
        thumbnail = PostcardExport.makeCGImage(
            document: copy,
            page: .design(contact: previewContact),
            dpi: 46
        )
    }
}

private struct ElementRow: View {
    var element: DesignElement
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: element.symbolName)
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(element.name)
                        .font(.callout)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if element.isLocked {
                    Image(systemName: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        switch element {
        case .text(let text):
            text.text.replacingOccurrences(of: "\n", with: " ").prefix(18).description
        case .motif(let motif):
            motif.kind.label
        case .shape(let shape):
            shape.kind.label
        case .image:
            "画像"
        }
    }
}

/// フォント選択用の一覧。日本語が出せるフォントだけを拾う。
enum FontCatalog {
    static func choices() -> [FontChoice] {
        FontChoice.allCases
    }

    static func installedJapaneseFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            let ctFont = font as CTFont
            var characters: [UniChar] = Array("日本語あ".utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            return CTFontGetGlyphsForCharacters(ctFont, &characters, &glyphs, characters.count)
        }
    }
}
