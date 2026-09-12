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

        Window("年賀スタジオの使い方", id: "help") {
            HelpView()
        }
        .defaultSize(width: 620, height: 620)
    }
}

/// アプリ共通のメニュー。
struct NengaCommands: Commands {
    @FocusedValue(\.documentActions) private var actions
    @Environment(\.openWindow) private var openWindow

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
            Button("年賀スタジオの使い方") {
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: .command)
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

/// ヘルプメニューから開く使い方の説明。
struct HelpView: View {
    private let steps: [(String, String)] = [
        ("1. 差出人を入力", "「設定」で自分の住所・氏名・電話番号を入力します。年（既定は翌年）もここで変えられます。"),
        ("2. 住所録を用意", "「住所録」で 1 件ずつ追加するか、⌘⇧I で CSV を取り込みます。サンプル住所録で試すこともできます。"),
        ("3. 文面を作る", "「文面デザイン」でテンプレートを選び、文字・写真・モチーフを足して調整します。ドラッグで移動、四隅で大きさの変更です。"),
        ("4. 宛名を調整", "「宛名印刷」で宛名面のプレビューを確認し、フォントや連名の扱い、郵便番号枠の位置を整えます。"),
        ("5. 位置合わせ", "「位置合わせシートを印刷」を実行し、実際のはがきを重ねてずれを測ります。ずれた分は「左右の補正」「上下の補正」で調整します。"),
        ("6. 印刷", "宛名面を印刷したら、文面を印刷します。用紙の向きは 4 通りから選べるので、最初は 1 枚だけ試してください。"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("年賀スタジオの使い方")
                        .font(.title2.bold())
                    Text("はがきは 100×148mm。住所録・文面・宛名を 1 つの書類（.nenga）にまとめます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                ForEach(steps, id: \.0) { step in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.0)
                            .font(.headline)
                        Text(step.1)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("印刷のこつ")
                        .font(.headline)
                    Text("・官製はがきは郵便番号枠が印刷済みなので「数字だけ印刷」を選びます。")
                    Text("・お年玉くじ番号の帯（下部 約 12mm）には宛名がかからないようにしています。")
                    Text("・文面ははがきの外形で切り取られるため、紙の外へはみ出した絵柄は印刷されません。")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
