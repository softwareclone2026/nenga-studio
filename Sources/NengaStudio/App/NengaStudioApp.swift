import AppKit
import NengaCore
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// .nenga（フォルダ型のパッケージ）を表す独自の UTType。
    static let nengaDocument = UTType(exportedAs: "com.softwareclone.nengastudio.document", conformingTo: .package)
}

struct NengaStudioApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: { NengaProjectDocument() }) { configuration in
            ContentView(document: configuration.document)
        }
        .commands {
            NengaCommands()
        }
        .defaultSize(width: 1180, height: 760)

        Settings {
            AboutView()
        }
    }
}

/// アプリ共通のメニュー。
struct NengaCommands: Commands {
    @FocusedValue(\.documentActions) private var actions

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("サンプル住所録を読み込む") {
                actions?.loadSampleContacts()
            }
            .disabled(actions == nil)
        }
        CommandGroup(after: .saveItem) {
            Divider()
            Button("住所録を CSV から取り込む…") {
                actions?.importCSV()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .disabled(actions == nil)
            Button("住所録を CSV に書き出す…") {
                actions?.exportCSV()
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(actions == nil)
            Divider()
            Button("宛名面を PDF に書き出す…") {
                actions?.exportAddressPDF()
            }
            .disabled(actions == nil)
            Button("文面を PDF に書き出す…") {
                actions?.exportDesignPDF()
            }
            .disabled(actions == nil)
            Button("位置合わせシートを印刷…") {
                actions?.printCalibrationSheet()
            }
            .disabled(actions == nil)
        }
        CommandGroup(replacing: .help) {
            Link("使い方（README）", destination: URL(string: "https://example.com")!)
        }
    }
}

/// メニューから現在の書類を操作するためのフック。
struct DocumentActions {
    var loadSampleContacts: () -> Void
    var importCSV: () -> Void
    var exportCSV: () -> Void
    var exportAddressPDF: () -> Void
    var exportDesignPDF: () -> Void
    var printCalibrationSheet: () -> Void
}

private struct DocumentActionsKey: FocusedValueKey {
    typealias Value = DocumentActions
}

extension FocusedValues {
    var documentActions: DocumentActions? {
        get { self[DocumentActionsKey.self] }
        set { self[DocumentActionsKey.self] = newValue }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.open")
                .font(.system(size: 42))
                .foregroundStyle(.tint)
            Text("年賀スタジオ")
                .font(.title2.bold())
            Text("macOS 版 年賀状ソフト")
                .foregroundStyle(.secondary)
            Text("住所録・文面作成・宛名印刷をひとつに。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(width: 380, height: 260)
    }
}
