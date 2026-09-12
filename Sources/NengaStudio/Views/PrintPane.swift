import NengaCore
import PDFKit
import SwiftUI

/// 宛名印刷の画面。左に印刷対象、中央にプレビュー、右にレイアウト設定。
struct PrintPane: View {
    @ObservedObject var document: NengaProjectDocument
    @Binding var previewContactID: UUID?
    var onPrint: () -> Void
    var onExportPDF: () -> Void
    var onPrintCalibration: () -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var previewPDF: Data?
    @State private var showOnlyPrintable = true

    private var contacts: [Contact] {
        showOnlyPrintable ? document.model.printableContacts : document.model.contacts
    }

    private var previewContact: Contact? {
        if let previewContactID, let contact = document.model.contacts.first(where: { $0.id == previewContactID }) {
            return contact
        }
        return contacts.first
    }

    private var previewIndex: Int {
        guard let previewContact else { return 0 }
        return contacts.firstIndex { $0.id == previewContact.id } ?? 0
    }

    var body: some View {
        HSplitView {
            contactList
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 260)
            previewArea
                .frame(minWidth: 380)
            settingsColumn
                .frame(minWidth: 300, idealWidth: 330, maxWidth: 400)
        }
        .onAppear(perform: refreshPreview)
        .onChange(of: previewContactID) { _, _ in refreshPreview() }
        .onChange(of: document.model) { _, _ in refreshPreview() }
    }

    // MARK: - 対象一覧

    private var contactList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("印刷対象")
                    .font(.headline)
                Spacer()
                Text("\(document.model.printableContacts.count) 件")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            Toggle("印刷する宛先だけ表示", isOn: $showOnlyPrintable)
                .toggleStyle(.checkbox)
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            Divider()
            List(selection: $previewContactID) {
                ForEach(contacts) { contact in
                    HStack(spacing: 6) {
                        Image(systemName: contact.isPrintable ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(contact.isPrintable ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(contact.displayName)
                            Text(AddressFormatter.formattedPostalCode(contact.postalCode))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(contact.id)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("印刷する枚数: \(document.model.printableContacts.count) 枚")
                    .font(.callout)
                Button {
                    previewContactID = contacts.first?.id
                } label: {
                    Label("先頭の宛先を表示", systemImage: "arrow.uturn.backward")
                }
                .font(.caption)
            }
            .padding(10)
        }
    }

    // MARK: - プレビュー

    private var previewArea: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    step(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(previewIndex <= 0)
                Text("\(min(previewIndex + 1, max(contacts.count, 1))) / \(max(contacts.count, 1))")
                    .font(.callout.monospacedDigit())
                Button {
                    step(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(previewIndex >= contacts.count - 1)
                Divider().frame(height: 16)
                Text("用紙: \(paperLabel)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onPrint()
                } label: {
                    Label("印刷…", systemImage: "printer")
                }
                .keyboardShortcut("p", modifiers: .command)
                Button {
                    onExportPDF()
                } label: {
                    Label("PDF に書き出す", systemImage: "square.and.arrow.up")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            if let previewPDF {
                PDFPreviewView(data: previewPDF, pageIndex: 0)
            } else {
                ContentUnavailableView("プレビューを準備中", systemImage: "hourglass")
            }
            Divider()
            HStack {
                Text("このプレビューは実際の用紙の向き（回転込み）で表示しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(8)
        }
    }

    private var paperLabel: String {
        let size = PostcardExport.pageSizeMM(document.model)
        return "\(Int(size.width)) × \(Int(size.height)) mm／\(document.model.printRotation.label)"
    }

    private func step(_ delta: Int) {
        let next = previewIndex + delta
        guard contacts.indices.contains(next) else { return }
        previewContactID = contacts[next].id
    }

    private func refreshPreview() {
        guard let contact = previewContact else {
            previewPDF = nil
            return
        }
        previewPDF = try? PostcardExport.makePDF(
            document: document.model,
            pages: [.address(contact)],
            mode: .print,
            assetLoader: document.imageLoader()
        )
    }

    // MARK: - 設定

    private var settingsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PanelSection(
                    "郵便番号",
                    subtitle: "官製はがきは枠が印刷済みのため、数字だけを重ねます。ずれる場合は 0.5mm ずつ調整してください。"
                ) {
                    Picker("", selection: binding(\.postalCodeFrame.showsFrame)) {
                        Text("枠も印刷する（無地はがき）").tag(true)
                        Text("数字だけ印刷（官製はがき）").tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                    MillimeterField(label: "左からの位置", value: binding(\.postalCodeFrame.leftMM), range: 10...60)
                    MillimeterField(label: "上からの位置", value: binding(\.postalCodeFrame.topMM), range: 2...30)
                    MillimeterField(label: "枠の大きさ", value: binding(\.postalCodeFrame.boxWidthMM), range: 4...8)
                    MillimeterField(label: "数字のサイズ", value: binding(\.postalCodeFrame.digitSizeMM), range: 3...8, step: 0.1)
                    Button {
                        onPrintCalibration()
                    } label: {
                        Label("位置合わせシートを印刷", systemImage: "ruler")
                    }
                }

                PanelSection("宛名", subtitle: "氏名は住所の左（横書きでは下）に大きく入ります。") {
                    Picker("", selection: binding(\.direction)) {
                        ForEach(TextDirection.allCases, id: \.self) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    HStack {
                        Text("住所のフォント")
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: binding(\.addressFont)) {
                            ForEach(FontCatalog.choices(), id: \.self) { choice in
                                Text(choice.detailText).tag(choice)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    MillimeterField(label: "住所のサイズ", value: binding(\.addressSizeMM), range: 2...6, step: 0.1)
                    HStack {
                        Text("氏名のフォント")
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: binding(\.nameFont)) {
                            ForEach(FontCatalog.choices(), id: \.self) { choice in
                                Text(choice.detailText).tag(choice)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    MillimeterField(label: "氏名のサイズ", value: binding(\.nameSizeMM), range: 3...12, step: 0.1)
                    HStack {
                        Text("敬称")
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: binding(\.honorificPlacement)) {
                            ForEach(HonorificPlacement.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    HStack {
                        Text("連名")
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: binding(\.coRecipientLayout)) {
                            ForEach(CoRecipientLayout.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    Toggle("都道府県を省略する", isOn: binding(\.omitPrefecture))
                    Toggle("番地を「1丁目2番3号」に変換する", isOn: binding(\.convertChomeBanchi))
                    Toggle("会社名・部署名を住所の前に印刷する", isOn: binding(\.showCompany))
                    Toggle("ガイドを表示する", isOn: binding(\.showsGuides))
                }

                PanelSection("差出人", subtitle: "自分の住所・氏名を左下などに小さく印刷します。") {
                    Toggle("差出人を印刷する", isOn: binding(\.sender.isEnabled))
                    Picker("", selection: binding(\.sender.corner)) {
                        ForEach(SenderLayout.Corner.allCases, id: \.self) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    Picker("", selection: binding(\.sender.direction)) {
                        ForEach(TextDirection.allCases, id: \.self) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    MillimeterField(label: "文字サイズ", value: binding(\.sender.sizeMM), range: 1.6...4, step: 0.1)
                    MillimeterField(label: "余白", value: binding(\.sender.marginMM), range: 3...20)
                    Toggle("郵便番号を印刷する", isOn: binding(\.sender.showsPostalCode))
                    Toggle("電話番号を印刷する", isOn: binding(\.sender.showsPhone))
                    Toggle("メールを印刷する", isOn: binding(\.sender.showsEmail))
                    if document.model.sender.isEmpty {
                        Text("「設定」画面で差出人を入力してください。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                PanelSection("用紙とプリンタ補正", subtitle: "最初はテスト印刷で向きと位置を確認してください。") {
                    HStack {
                        Text("用紙の送り方")
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: documentBinding(\.printRotation)) {
                            ForEach(PrintRotation.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    HStack {
                        Text("はがきの種類")
                            .frame(width: 110, alignment: .leading)
                        Picker("", selection: binding(\.paper.kind)) {
                            ForEach(PostcardPaper.Kind.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    MillimeterField(label: "左右の補正", value: binding(\.offsetXMM), range: -5...5, step: 0.5)
                    MillimeterField(label: "上下の補正", value: binding(\.offsetYMM), range: -5...5, step: 0.5)
                }
            }
            .padding(12)
        }
    }

    /// AddressLayout の中の値を直接書き換えるバインディング。
    private func binding<T>(_ keyPath: WritableKeyPath<AddressLayout, T>) -> Binding<T> {
        Binding(
            get: { document.model.addressLayout[keyPath: keyPath] },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "レイアウトを変更") { model in
                    model.addressLayout[keyPath: keyPath] = newValue
                }
            }
        )
    }

    /// 文書全体の設定を書き換えるバインディング。
    private func documentBinding<T>(_ keyPath: WritableKeyPath<NengaDocument, T>) -> Binding<T> {
        Binding(
            get: { document.model[keyPath: keyPath] },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "設定を変更") { model in
                    model[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
