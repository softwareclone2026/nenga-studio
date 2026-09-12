import NengaCore
import SwiftUI

/// プロジェクト全体の設定と差出人情報。
struct SettingsPane: View {
    @ObservedObject var document: NengaProjectDocument
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PanelSection("年賀状の年", subtitle: "干支と和暦は自動で切り替わります。") {
                    HStack {
                        Text("年")
                            .frame(width: 96, alignment: .leading)
                        TextField("", value: yearBinding, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Stepper("", value: yearBinding, in: 2020...2100)
                            .labelsHidden()
                        Spacer()
                    }
                    .font(.callout)
                    HStack(spacing: 16) {
                        Label(document.model.yearInfo.wareki, systemImage: "calendar")
                        Label(document.model.yearInfo.zodiacLabel, systemImage: "hare")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    HStack {
                        Text("干支に合わせて文面を切り替え")
                            .font(.callout)
                        Spacer()
                        ForEach(NengaTemplates.all.filter(\.usesZodiac).prefix(3)) { template in
                            Button(template.name) {
                                document.update(undoManager: undoManager, actionName: "テンプレートを適用") { model in
                                    model.design = template.make(model.year)
                                }
                            }
                            .controlSize(.small)
                        }
                    }
                }

                PanelSection("差出人（自分）の情報", subtitle: "宛名面の左下などに印刷されます。") {
                    LabeledTextField(label: "姓", text: senderBinding(\.familyName))
                    LabeledTextField(label: "名", text: senderBinding(\.givenName))
                    LabeledTextField(label: "郵便番号", text: senderBinding(\.postalCode), prompt: "1000001")
                    LabeledTextField(label: "住所 1", text: senderBinding(\.address1), prompt: "東京都千代田区")
                    LabeledTextField(label: "住所 2", text: senderBinding(\.address2), prompt: "千代田1-1-1")
                    LabeledTextField(label: "電話番号", text: senderBinding(\.phone))
                    LabeledTextField(label: "メール", text: senderBinding(\.email))
                }

                PanelSection("文面", subtitle: "はがきサイズは 100×148mm 固定です。") {
                    ColorPickerRow(label: "用紙の色", color: paperColorBinding)
                    HStack {
                        Text("文面をリセット")
                            .font(.callout)
                        Spacer()
                        Button("白紙にする") {
                            document.update(undoManager: undoManager, actionName: "文面を白紙にする") { model in
                                model.design = DesignPage(
                                    paperColor: model.design.paperColor,
                                    elements: [],
                                    templateID: nil
                                )
                            }
                        }
                    }
                }

                PanelSection("この書類") {
                    HStack {
                        Text("住所録")
                        Spacer()
                        Text("\(document.model.contacts.count) 件")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    HStack {
                        Text("文面の要素")
                        Spacer()
                        Text("\(document.model.design.elements.count) 個")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    HStack {
                        Text("写真")
                        Spacer()
                        Text("\(document.assets.count) 点")
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                    Text("保存すると 1 つの .nenga ファイル（パッケージ）に住所録・文面・写真がまとめて保存されます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                PanelSection("データの取り込みと書き出し") {
                    Text("CSV の取り込み・書き出しは「ファイル」メニュー、または住所録画面のツールバーから行えます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }

    private var yearBinding: Binding<Int> {
        Binding(
            get: { document.model.year },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "年を変更") { model in
                    model.year = min(max(newValue, 2020), 2100)
                }
            }
        )
    }

    private var paperColorBinding: Binding<NengaCore.RGBColor> {
        Binding(
            get: { document.model.design.paperColor },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "用紙の色を変更") { model in
                    model.design.paperColor = newValue
                }
            }
        )
    }

    private func senderBinding<T>(_ keyPath: WritableKeyPath<SenderProfile, T>) -> Binding<T> {
        Binding(
            get: { document.model.sender[keyPath: keyPath] },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "差出人を編集") { model in
                    model.sender[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
