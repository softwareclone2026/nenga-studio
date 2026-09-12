import NengaCore
import SwiftUI

struct ContactInspector: View {
    @Binding var contact: Contact
    var groups: [String]
    var onDelete: () -> Void
    var onDuplicate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PanelSection("宛名", subtitle: "年賀状に印刷される内容です") {
                    LabeledTextField(label: "姓", text: $contact.familyName)
                    LabeledTextField(label: "名", text: $contact.givenName)
                    HStack {
                        Text("敬称")
                            .frame(width: 96, alignment: .leading)
                        Picker("", selection: $contact.honorific) {
                            ForEach(Honorific.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                        Spacer()
                    }
                    .font(.callout)
                    HStack {
                        Text("書字方向")
                            .frame(width: 96, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { contact.verticalOverride == true ? 0 : (contact.verticalOverride == false ? 1 : 2) },
                            set: { contact.verticalOverride = $0 == 2 ? nil : ($0 == 0) }
                        )) {
                            Text("縦書き").tag(0)
                            Text("横書き").tag(1)
                            Text("文書の既定").tag(2)
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Spacer()
                    }
                    .font(.callout)
                }

                PanelSection("住所") {
                    LabeledTextField(label: "郵便番号", text: $contact.postalCode, prompt: "1500001")
                    LabeledTextField(label: "住所 1", text: $contact.address1, prompt: "東京都渋谷区")
                    LabeledTextField(label: "住所 2", text: $contact.address2, prompt: "神宮前1-2-3 ○○マンション")
                    LabeledTextField(label: "会社名", text: $contact.company)
                    LabeledTextField(label: "部署・役職", text: $contact.department)
                    LabeledTextField(label: "電話番号", text: $contact.phone)
                    LabeledTextField(label: "メール", text: $contact.email)
                }

                PanelSection("連名", subtitle: "ご家族・ご夫婦などの連名") {
                    if contact.coRecipients.isEmpty {
                        Text("連名はありません")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(contact.coRecipients.indices, id: \.self) { index in
                        HStack {
                            TextField("お名前", text: Binding(
                                get: { contact.coRecipients[safe: index]?.name ?? "" },
                                set: { contact.coRecipients[index].name = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            Picker("", selection: Binding(
                                get: { contact.coRecipients[safe: index]?.honorific ?? .sama },
                                set: { contact.coRecipients[index].honorific = $0 }
                            )) {
                                ForEach(Honorific.allCases, id: \.self) { value in
                                    Text(value.label).tag(value)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 110)
                            Button {
                                contact.coRecipients.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button {
                        contact.coRecipients.append(CoRecipient())
                    } label: {
                        Label("連名を追加", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }

                PanelSection("管理") {
                    HStack {
                        Text("状態")
                            .frame(width: 96, alignment: .leading)
                        Picker("", selection: $contact.status) {
                            ForEach(SendStatus.allCases, id: \.self) { value in
                                Text(value.label).tag(value)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                        Spacer()
                    }
                    .font(.callout)
                    HStack {
                        Text("グループ")
                            .frame(width: 96, alignment: .leading)
                        TextField("友人・親戚など", text: $contact.group)
                            .textFieldStyle(.roundedBorder)
                        if !groups.isEmpty {
                            Menu {
                                ForEach(groups, id: \.self) { group in
                                    Button(group) { contact.group = group }
                                }
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 24)
                        }
                    }
                    .font(.callout)
                    Toggle("印刷対象に含める", isOn: $contact.isPrintable)
                        .font(.callout)
                    LabeledTextField(label: "備考", text: $contact.note)
                }

                PanelSection("この宛先の操作") {
                    HStack {
                        Button {
                            onDuplicate()
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
            }
            .padding(12)
        }
    }
}
