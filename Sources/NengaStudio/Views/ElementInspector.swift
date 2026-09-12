import AppKit
import NengaCore
import SwiftUI
import UniformTypeIdentifiers

struct ElementInspector: View {
    @ObservedObject var document: NengaProjectDocument
    var elementID: UUID
    var onDelete: () -> Void

    @Environment(\.undoManager) private var undoManager

    private var element: DesignElement? {
        document.model.design[elementID]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let element {
                PanelSection("配置", subtitle: element.kindLabel) {
                    LabeledTextField(label: "名前", text: nameBinding)
                    MillimeterField(label: "左", value: frameBinding(\.x), range: -50...200)
                    MillimeterField(label: "上", value: frameBinding(\.y), range: -50...200)
                    MillimeterField(label: "幅", value: frameBinding(\.width), range: 2...200)
                    MillimeterField(label: "高さ", value: frameBinding(\.height), range: 2...200)
                    HStack {
                        Text("回転")
                            .frame(width: 96, alignment: .leading)
                        Slider(value: frameBinding(\.rotationDegrees), in: -180...180)
                        Text("\(Int(element.frame.rotationDegrees))°")
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                    .font(.callout)
                    HStack {
                        Text("不透明度")
                            .frame(width: 96, alignment: .leading)
                        Slider(value: opacityBinding, in: 0.05...1)
                        Text("\(Int(element.opacity * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                    .font(.callout)
                    Toggle("編集をロック", isOn: lockBinding)
                        .font(.callout)
                }

                switch element {
                case .text(let text):
                    textSection(text)
                case .shape(let shape):
                    shapeSection(shape)
                case .motif(let motif):
                    motifSection(motif)
                case .image(let image):
                    imageSection(image)
                }

                PanelSection("重ね順と操作") {
                    HStack {
                        Button {
                            document.update(undoManager: undoManager, actionName: "前面へ") { $0.design.bringForward(elementID) }
                        } label: {
                            Label("前面へ", systemImage: "square.3.layers.3d.top.filled")
                        }
                        Button {
                            document.update(undoManager: undoManager, actionName: "背面へ") { $0.design.sendBackward(elementID) }
                        } label: {
                            Label("背面へ", systemImage: "square.3.layers.3d.bottom.filled")
                        }
                    }
                    HStack {
                        Button {
                            duplicate(element)
                        } label: {
                            Label("複製", systemImage: "plus.square.on.square")
                        }
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            } else {
                Text("要素を選ぶと設定が表示されます")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - テキスト

    @ViewBuilder
    private func textSection(_ text: TextElement) -> some View {
        PanelSection("文字", subtitle: "縦書き・横書きとフォントを選べます") {
            TextEditor(text: textBinding(\.text))
                .frame(height: 74)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.12)))
            HStack {
                Picker("", selection: textBinding(\.direction)) {
                    ForEach(TextDirection.allCases, id: \.self) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                Picker("", selection: textBinding(\.alignment)) {
                    ForEach(TextAlignmentOption.allCases, id: \.self) { value in
                        Text(value.label).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
                Spacer()
            }
            fontPicker(text)
            HStack {
                Text("サイズ")
                    .frame(width: 96, alignment: .leading)
                Slider(value: textBinding(\.sizeMM), in: 2...24)
                Text(String(format: "%.1fmm", text.sizeMM))
                    .font(.caption.monospacedDigit())
                    .frame(width: 56, alignment: .trailing)
            }
            .font(.callout)
            ColorPickerRow(label: "文字色", color: textBinding(\.color))
            MillimeterField(label: "字間", value: textBinding(\.letterSpacingMM), range: -2...6, step: 0.1)
            MillimeterField(label: "行間", value: textBinding(\.lineSpacingMM), range: -2...12, step: 0.1)
            Toggle("宛名を差し込む（{姓} {名} {連名} など）", isOn: textBinding(\.usesPlaceholders))
                .font(.callout)
            if text.usesPlaceholders {
                HStack(spacing: 4) {
                    ForEach(Placeholder.tokens, id: \.self) { token in
                        Button(token) {
                            var updated = text
                            updated.text += token
                            document.update(undoManager: undoManager, actionName: "差し込みを追加") { model in
                                model.design[elementID] = .text(updated)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fontPicker(_ text: TextElement) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("フォント")
                    .frame(width: 96, alignment: .leading)
                Picker("", selection: fontBinding) {
                    ForEach(FontCatalog.choices(), id: \.self) { choice in
                        Text(choice.detailText).tag(choice)
                    }
                }
                .labelsHidden()
                Spacer()
            }
            HStack {
                Text("その他")
                    .frame(width: 96, alignment: .leading)
                Picker("", selection: customFontBinding) {
                    Text("（組み込みから選ぶ）").tag("")
                    ForEach(FontCatalog.installedJapaneseFamilies(), id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                .labelsHidden()
                Spacer()
            }
            HStack {
                Text("太さ")
                    .frame(width: 96, alignment: .leading)
                Picker("", selection: textBinding(\.weight)) {
                    ForEach(FontWeight.allCases, id: \.self) { value in
                        Text(value.label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 130)
                Spacer()
            }
        }
        .font(.callout)
    }

    // MARK: - 図形

    @ViewBuilder
    private func shapeSection(_ shape: ShapeElement) -> some View {
        PanelSection("図形") {
            HStack {
                Text("種類")
                    .frame(width: 96, alignment: .leading)
                Picker("", selection: shapeBinding(\.kind)) {
                    ForEach(ShapeKind.allCases, id: \.self) { value in
                        Text(value.label).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                Spacer()
            }
            .font(.callout)
            optionalColorRow(label: "塗り", value: shapeBinding(\.fill), fallback: NengaCore.RGBColor(hex: "FFFFFF"))
            optionalColorRow(label: "線", value: shapeBinding(\.stroke), fallback: NengaCore.RGBColor(hex: "C9A227"))
            MillimeterField(label: "線の太さ", value: shapeBinding(\.strokeWidthMM), range: 0.05...3, step: 0.05)
            MillimeterField(label: "角の丸み", value: shapeBinding(\.cornerRadiusMM), range: 0...20)
        }
    }

    // MARK: - モチーフ

    @ViewBuilder
    private func motifSection(_ motif: MotifElement) -> some View {
        PanelSection("モチーフ") {
            HStack {
                Text("絵柄")
                    .frame(width: 96, alignment: .leading)
                Picker("", selection: motifBinding(\.kind)) {
                    ForEach(MotifKind.allCases, id: \.self) { value in
                        Text(value.label).tag(value)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                Spacer()
            }
            .font(.callout)
            HStack {
                Text("配色")
                    .frame(width: 96, alignment: .leading)
                Picker("", selection: motifBinding(\.paletteName)) {
                    ForEach(Palette.all, id: \.name) { palette in
                        Text(palette.name).tag(palette.name)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                Spacer()
            }
            .font(.callout)
            optionalColorRow(label: "メインの色", value: motifBinding(\.overrideColor), fallback: motif.palette.primary)
            MillimeterField(label: "線の太さ", value: motifBinding(\.lineWidthMM), range: 0.1...2, step: 0.05)
            Text("メインの色を指定すると、モチーフの主要な色をその色に置き換えます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 画像

    @ViewBuilder
    private func imageSection(_ image: ImageElement) -> some View {
        PanelSection("写真") {
            LabeledTextField(label: "ファイル", text: .constant(displayFileName))
                .disabled(true)
            MillimeterField(label: "角の丸み", value: imageBinding(\.cornerRadiusMM), range: 0...20)
            Button {
                replaceImage(image)
            } label: {
                Label("写真を差し替える…", systemImage: "photo.on.rectangle.angled")
            }
        }
    }

    private var displayFileName: String {
        if case .image(let image)? = element {
            return image.assetFileName.isEmpty ? "（未設定）" : image.assetFileName
        }
        return ""
    }

    private func replaceImage(_ image: ImageElement) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .image]
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        let fileName = document.addAsset(data: data, fileName: url.lastPathComponent)
        var updated = image
        updated.assetFileName = fileName
        updated.name = url.deletingPathExtension().lastPathComponent
        document.update(undoManager: undoManager, actionName: "写真を差し替え") { model in
            model.design[elementID] = .image(updated)
        }
    }

    // MARK: - 共通のバインディング

    private func update(_ actionName: String, _ mutation: @escaping (inout DesignElement) -> Void) {
        document.update(undoManager: undoManager, actionName: actionName) { model in
            guard var current = model.design[elementID] else { return }
            mutation(&current)
            model.design[elementID] = current
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { element?.name ?? "" },
            set: { newValue in update("名前を変更") { $0.name = newValue } }
        )
    }

    private var opacityBinding: Binding<Double> {
        Binding(
            get: { element?.opacity ?? 1 },
            set: { newValue in update("不透明度を変更") { $0.opacity = newValue } }
        )
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { element?.isLocked ?? false },
            set: { newValue in update("ロックを切り替え") { $0.isLocked = newValue } }
        )
    }

    private func frameBinding(_ keyPath: WritableKeyPath<ElementFrame, Double>) -> Binding<Double> {
        Binding(
            get: { element?.frame[keyPath: keyPath] ?? 0 },
            set: { newValue in update("配置を変更") { $0.frame[keyPath: keyPath] = newValue } }
        )
    }

    private func textBinding<T>(_ keyPath: WritableKeyPath<TextElement, T>) -> Binding<T> {
        Binding(
            get: {
                if case .text(let text)? = element { return text[keyPath: keyPath] }
                return TextElement(frame: ElementFrame(x: 0, y: 0, width: 1, height: 1), text: "")[keyPath: keyPath]
            },
            set: { newValue in
                update("テキストを編集") { element in
                    if case .text(var text) = element {
                        text[keyPath: keyPath] = newValue
                        element = .text(text)
                    }
                }
            }
        )
    }

    private var fontBinding: Binding<FontChoice> {
        Binding(
            get: {
                if case .text(let text)? = element { return text.font }
                return .mincho
            },
            set: { newValue in
                update("フォントを変更") { element in
                    if case .text(var text) = element {
                        text.font = newValue
                        element = .text(text)
                    }
                }
            }
        )
    }

    private var customFontBinding: Binding<String> {
        Binding(
            get: {
                if case .text(let text)? = element, case .custom(let name) = text.font { return name }
                return ""
            },
            set: { newValue in
                update("フォントを変更") { element in
                    if case .text(var text) = element {
                        text.font = newValue.isEmpty ? .mincho : .custom(newValue)
                        element = .text(text)
                    }
                }
            }
        )
    }

    private func shapeBinding<T>(_ keyPath: WritableKeyPath<ShapeElement, T>) -> Binding<T> {
        Binding(
            get: {
                if case .shape(let shape)? = element { return shape[keyPath: keyPath] }
                return ShapeElement(frame: ElementFrame(x: 0, y: 0, width: 1, height: 1))[keyPath: keyPath]
            },
            set: { newValue in
                update("図形を編集") { element in
                    if case .shape(var shape) = element {
                        shape[keyPath: keyPath] = newValue
                        element = .shape(shape)
                    }
                }
            }
        )
    }

    private func motifBinding<T>(_ keyPath: WritableKeyPath<MotifElement, T>) -> Binding<T> {
        Binding(
            get: {
                if case .motif(let motif)? = element { return motif[keyPath: keyPath] }
                return MotifElement(frame: ElementFrame(x: 0, y: 0, width: 1, height: 1), kind: .plum)[keyPath: keyPath]
            },
            set: { newValue in
                update("モチーフを編集") { element in
                    if case .motif(var motif) = element {
                        motif[keyPath: keyPath] = newValue
                        element = .motif(motif)
                    }
                }
            }
        )
    }

    private func imageBinding<T>(_ keyPath: WritableKeyPath<ImageElement, T>) -> Binding<T> {
        Binding(
            get: {
                if case .image(let image)? = element { return image[keyPath: keyPath] }
                return ImageElement(frame: ElementFrame(x: 0, y: 0, width: 1, height: 1), assetFileName: "")[keyPath: keyPath]
            },
            set: { newValue in
                update("写真を編集") { element in
                    if case .image(var image) = element {
                        image[keyPath: keyPath] = newValue
                        element = .image(image)
                    }
                }
            }
        )
    }

    /// nil を許す色（図形の塗り・線など）。
    @ViewBuilder
    private func optionalColorRow(label: String, value: Binding<NengaCore.RGBColor?>, fallback: NengaCore.RGBColor) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { value.wrappedValue != nil },
                set: { newValue in value.wrappedValue = newValue ? fallback : nil }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            ColorPickerRow(
                label: label,
                color: Binding(
                    get: { value.wrappedValue ?? fallback },
                    set: { value.wrappedValue = $0 }
                )
            )
            .opacity(value.wrappedValue == nil ? 0.4 : 1)
            .disabled(value.wrappedValue == nil)
        }
    }

    private func duplicate(_ element: DesignElement) {
        var copy = element
        let newID = UUID()
        copy.frame.x += 4
        copy.frame.y += 4
        switch copy {
        case .text(var text):
            text.id = newID
            copy = .text(text)
        case .shape(var shape):
            shape.id = newID
            copy = .shape(shape)
        case .motif(var motif):
            motif.id = newID
            copy = .motif(motif)
        case .image(var image):
            image.id = newID
            copy = .image(image)
        }
        document.update(undoManager: undoManager, actionName: "要素を複製") { model in
            model.design.elements.append(copy)
        }
    }
}
