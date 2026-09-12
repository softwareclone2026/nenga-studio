import AppKit
import NengaCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

enum AppSection: String, CaseIterable, Identifiable {
    case addressBook
    case design
    case printing
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addressBook: "住所録"
        case .design: "文面デザイン"
        case .printing: "宛名印刷"
        case .settings: "設定"
        }
    }

    var symbol: String {
        switch self {
        case .addressBook: "person.2"
        case .design: "paintbrush"
        case .printing: "printer"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @ObservedObject var document: NengaProjectDocument
    @Environment(\.undoManager) private var undoManager

    @State private var section: AppSection = .addressBook
    @State private var selectedContactID: UUID?
    @State private var selectedElementID: UUID?
    @State private var previewContactID: UUID?
    @State private var alertMessage: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(minWidth: 720, minHeight: 520)
        }
        .navigationTitle(navigationTitle)
        .focusedSceneValue(\.documentActions, documentActions)
        .alert("年賀スタジオ", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            if document.model.design.elements.isEmpty,
               let page = NengaTemplates.template(id: NengaTemplates.defaultTemplateID, year: document.model.year) {
                document.model.design = page
            }
            selectedContactID = document.model.contacts.first?.id
            previewContactID = document.model.printableContacts.first?.id ?? document.model.contacts.first?.id
        }
    }

    private var navigationTitle: String {
        let year = String(document.model.year)
        let name = document.model.sender.fullName
        return name.isEmpty ? "年賀状 " + year + "年" : "年賀状 " + year + "年（" + name + "）"
    }

    private var sidebar: some View {
        List(selection: $section) {
            Section("年賀状 " + String(document.model.year) + "年") {
                ForEach(AppSection.allCases) { item in
                    Label(item.title, systemImage: item.symbol)
                        .tag(item)
                }
            }
            Section("このファイル") {
                SidebarStatRow(title: "住所録", value: "\(document.model.contacts.count) 件")
                SidebarStatRow(title: "印刷対象", value: "\(document.model.printableContacts.count) 件")
                SidebarStatRow(title: "喪中", value: "\(document.model.contacts.filter { $0.status == .mourning }.count) 件")
                SidebarStatRow(title: "干支", value: document.model.yearInfo.zodiacLabel)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .addressBook:
            AddressBookPane(
                document: document,
                selection: $selectedContactID,
                onImportCSV: importCSV,
                onExportCSV: exportCSV,
                onAddSample: loadSampleContacts
            )
        case .design:
            DesignPane(
                document: document,
                selectedElementID: $selectedElementID,
                previewContactID: $previewContactID
            )
        case .printing:
            PrintPane(
                document: document,
                previewContactID: $previewContactID,
                onPrint: printAddressSheets,
                onExportPDF: exportAddressPDF,
                onPrintCalibration: printCalibrationSheet
            )
        case .settings:
            SettingsPane(document: document)
        }
    }

    // MARK: - メニュー連携

    private var documentActions: DocumentActions {
        DocumentActions(
            loadSampleContacts: loadSampleContacts,
            importCSV: importCSV,
            exportCSV: exportCSV,
            exportAddressPDF: exportAddressPDF,
            exportDesignPDF: exportDesignPDF,
            printCalibrationSheet: printCalibrationSheet
        )
    }

    // MARK: - 住所録

    private func loadSampleContacts() {
        document.update(undoManager: undoManager, actionName: "サンプル住所録を読み込む") { model in
            model.contacts = SampleContacts.make()
        }
        selectedContactID = document.model.contacts.first?.id
        previewContactID = document.model.printableContacts.first?.id
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .data]
        panel.allowsMultipleSelection = false
        panel.message = "住所録の CSV（UTF-8 / Shift-JIS）を選んでください。"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let result = try AddressBookCSV.importContacts(from: data)
            guard !result.contacts.isEmpty else {
                alertMessage = "取り込める行がありませんでした。"
                return
            }
            document.update(undoManager: undoManager, actionName: "CSV を取り込む") { model in
                model.contacts.append(contentsOf: result.contacts)
            }
            previewContactID = document.model.printableContacts.first?.id ?? document.model.contacts.first?.id
            var message = "\(result.contacts.count) 件を取り込みました（\(result.detectedEncoding)）。"
            if !result.warnings.isEmpty {
                message += "\n\n" + result.warnings.prefix(5).joined(separator: "\n")
            }
            alertMessage = message
        } catch {
            alertMessage = "取り込みに失敗しました: \(error.localizedDescription)"
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "住所録.csv"
        panel.message = "書き出す文字コードを選べます（既定は UTF-8 / BOM 付き）。"
        let accessory = CSVExportAccessory()
        panel.accessoryView = accessory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let data = AddressBookCSV.exportData(contacts: document.model.contacts, encoding: accessory.encoding)
        do {
            try data.write(to: url, options: .atomic)
            alertMessage = "\(document.model.contacts.count) 件を書き出しました。"
        } catch {
            alertMessage = "書き出しに失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - 印刷と PDF

    private func addressPDFData() throws -> Data {
        let pages = document.model.printableContacts.map { PostcardPage.address($0) }
        return try PostcardExport.makePDF(
            document: document.model,
            pages: pages.isEmpty ? [.calibration] : pages,
            mode: .print,
            assetLoader: document.imageLoader()
        )
    }

    private func exportAddressPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "宛名面-\(document.model.year).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try addressPDFData().write(to: url, options: .atomic)
            alertMessage = "宛名面の PDF を書き出しました（\(document.model.printableContacts.count) 枚）。"
        } catch {
            alertMessage = "書き出しに失敗しました: \(error.localizedDescription)"
        }
    }

    private func exportDesignPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "文面-\(document.model.year).pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try PostcardExport.makePDF(
                document: document.model,
                pages: [.design(contact: document.model.contacts.first)],
                mode: .print,
                assetLoader: document.imageLoader()
            )
            try data.write(to: url, options: .atomic)
            alertMessage = "文面の PDF を書き出しました。"
        } catch {
            alertMessage = "書き出しに失敗しました: \(error.localizedDescription)"
        }
    }

    private func printAddressSheets() {
        let pages = document.model.printableContacts.map { PostcardPage.address($0) }
        if let message = PostcardPrinting.print(
            document: document.model,
            pages: pages.isEmpty ? [.calibration] : pages,
            jobName: "年賀状 宛名面 " + String(document.model.year),
            assetLoader: document.imageLoader()
        ) {
            alertMessage = message
        }
    }

    private func printCalibrationSheet() {
        if let message = PostcardPrinting.print(
            document: document.model,
            pages: [.calibration],
            jobName: "年賀状 位置合わせシート",
            assetLoader: document.imageLoader()
        ) {
            alertMessage = message
        }
    }
}

private struct SidebarStatRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }
}

/// CSV 書き出しの文字コードを選ぶアクセサリ。
final class CSVExportAccessory: NSView {
    private let popup = NSPopUpButton()
    var encoding: AddressBookCSV.TextEncoding = .utf8WithBOM

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 56))
        let label = NSTextField(labelWithString: "文字コード:")
        label.frame = NSRect(x: 12, y: 18, width: 80, height: 20)
        popup.frame = NSRect(x: 96, y: 14, width: 210, height: 26)
        popup.addItems(withTitles: AddressBookCSV.TextEncoding.allCases.map(\.label))
        popup.selectItem(at: AddressBookCSV.TextEncoding.allCases.firstIndex(of: .utf8WithBOM) ?? 0)
        popup.target = self
        popup.action = #selector(selectionChanged)
        addSubview(label)
        addSubview(popup)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func selectionChanged() {
        let all = AddressBookCSV.TextEncoding.allCases
        let index = popup.indexOfSelectedItem
        if all.indices.contains(index) {
            encoding = all[index]
        }
    }
}
