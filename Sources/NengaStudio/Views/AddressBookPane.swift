import NengaCore
import SwiftUI

enum ContactFilter: String, CaseIterable, Identifiable {
    case all
    case printable
    case received
    case mourning
    case skipped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "すべて"
        case .printable: "印刷対象"
        case .received: "受領済み"
        case .mourning: "喪中"
        case .skipped: "送らない"
        }
    }
}

enum ContactSort: String, CaseIterable, Identifiable {
    case name
    case postalCode
    case group

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: "氏名順"
        case .postalCode: "郵便番号順"
        case .group: "グループ順"
        }
    }
}

struct AddressBookPane: View {
    @ObservedObject var document: NengaProjectDocument
    @Binding var selection: UUID?
    var onImportCSV: () -> Void
    var onExportCSV: () -> Void
    var onAddSample: () -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var searchText = ""
    @State private var filter: ContactFilter = .printable
    @State private var sort: ContactSort = .name

    private var contacts: [Contact] {
        document.model.contacts
    }

    private var displayedContacts: [Contact] {
        var result = contacts
        switch filter {
        case .all: break
        case .printable: result = result.filter { $0.isPrintable && $0.status != .mourning }
        case .received: result = result.filter { $0.status == .received }
        case .mourning: result = result.filter { $0.status == .mourning }
        case .skipped: result = result.filter { $0.status == .skip }
        }
        if !searchText.isEmpty {
            let needle = searchText
            result = result.filter {
                $0.displayName.contains(needle)
                || $0.fullAddress.contains(needle)
                || $0.postalCode.contains(needle)
                || $0.company.contains(needle)
                || $0.group.contains(needle)
            }
        }
        switch sort {
        case .name: result = result.sortedByName()
        case .postalCode: result = result.sortedByPostalCode()
        case .group: result = result.sorted { $0.group < $1.group }
        }
        return result
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filterBar
                Divider()
                if contacts.isEmpty {
                    emptyState
                } else {
                    table
                }
            }
            .frame(minWidth: 460)

            if let id = selection, let binding = contactBinding(id) {
                ContactInspector(
                    contact: binding,
                    groups: contacts.groups(),
                    onDelete: { deleteContacts([id]) },
                    onDuplicate: { duplicate(id) }
                )
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
            } else {
                ContentUnavailableView(
                    "住所録から 1 件選んでください",
                    systemImage: "person.text.rectangle",
                    description: Text("右側に宛名の詳細が表示されます。")
                )
                .frame(minWidth: 320)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    addContact()
                } label: {
                    Label("宛先を追加", systemImage: "plus")
                }
                Button {
                    if let id = selection { duplicate(id) }
                } label: {
                    Label("複製", systemImage: "plus.square.on.square")
                }
                .disabled(selection == nil)
                Button(role: .destructive) {
                    if let id = selection { deleteContacts([id]) }
                } label: {
                    Label("削除", systemImage: "trash")
                }
                .disabled(selection == nil)
                Divider()
                Button {
                    onImportCSV()
                } label: {
                    Label("CSV を取り込む", systemImage: "square.and.arrow.down")
                }
                Button {
                    onExportCSV()
                } label: {
                    Label("CSV に書き出す", systemImage: "square.and.arrow.up")
                }
                Menu {
                    Button("サンプル住所録を読み込む") { onAddSample() }
                    Button("印刷対象をすべて選択") { setAllPrintable(true) }
                    Button("印刷対象をすべて解除") { setAllPrintable(false) }
                    Button("喪中をすべて印刷対象から外す") { clearMourning() }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            TextField("氏名・住所・郵便番号で検索", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 260)
            Picker("表示", selection: $filter) {
                ForEach(ContactFilter.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Picker("並び", selection: $sort) {
                ForEach(ContactSort.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .frame(width: 140)
            Spacer()
            Text("\(displayedContacts.count) / \(contacts.count) 件")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(10)
    }

    /// 住所録が空のときの案内。新規書類では何も入っていない状態から始める。
    private var emptyState: some View {
        ContentUnavailableView {
            Label("住所録が空です", systemImage: "person.crop.rectangle.stack")
        } description: {
            Text("CSV から取り込むか、サンプルの住所録で試せます。")
        } actions: {
            Button {
                onAddSample()
            } label: {
                Label("サンプル住所録を読み込む", systemImage: "sparkles")
            }
            Button {
                onImportCSV()
            } label: {
                Label("CSV を取り込む", systemImage: "square.and.arrow.down")
            }
            Button {
                addContact()
            } label: {
                Label("宛先を 1 件追加", systemImage: "plus")
            }
        }
    }

    private var table: some View {
        Table(displayedContacts, selection: $selection) {
            TableColumn("印刷") { contact in
                Toggle("", isOn: printableBinding(contact.id))
                    .labelsHidden()
                    .toggleStyle(.checkbox)
            }
            .width(44)
            TableColumn("氏名") { contact in
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.displayName)
                    if !contact.company.isEmpty {
                        Text(contact.company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 120, ideal: 160)
            TableColumn("郵便番号") { contact in
                Text(AddressFormatter.formattedPostalCode(contact.postalCode))
                    .font(.callout.monospacedDigit())
            }
            .width(90)
            TableColumn("住所") { contact in
                Text(contact.fullAddress)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            .width(min: 180, ideal: 260)
            TableColumn("グループ") { contact in
                Text(contact.group)
                    .foregroundStyle(.secondary)
            }
            .width(80)
            TableColumn("状態") { contact in
                StatusBadge(status: contact.status, contact: contact)
            }
            .width(96)
        }
    }

    // MARK: - 編集

    private func contactBinding(_ id: UUID) -> Binding<Contact>? {
        guard let index = document.model.contacts.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { document.model.contacts[safe: index] ?? Contact(id: id) },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "宛先を編集") { model in
                    guard let current = model.contacts.firstIndex(where: { $0.id == id }) else { return }
                    model.contacts[current] = newValue
                }
            }
        )
    }

    private func printableBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { document.model.contacts.first { $0.id == id }?.isPrintable ?? false },
            set: { newValue in
                document.update(undoManager: undoManager, actionName: "印刷対象を切り替え") { model in
                    guard let index = model.contacts.firstIndex(where: { $0.id == id }) else { return }
                    model.contacts[index].isPrintable = newValue
                }
            }
        )
    }

    private func addContact() {
        var contact = Contact()
        contact.familyName = "新しい"
        contact.givenName = "宛先"
        document.update(undoManager: undoManager, actionName: "宛先を追加") { model in
            model.contacts.append(contact)
        }
        selection = contact.id
    }

    private func duplicate(_ id: UUID) {
        guard var contact = contacts.first(where: { $0.id == id }) else { return }
        contact.id = UUID()
        document.update(undoManager: undoManager, actionName: "宛先を複製") { model in
            guard let index = model.contacts.firstIndex(where: { $0.id == id }) else { return }
            model.contacts.insert(contact, at: index + 1)
        }
        selection = contact.id
    }

    private func deleteContacts(_ ids: [UUID]) {
        let targets = Set(ids)
        document.update(undoManager: undoManager, actionName: "宛先を削除") { model in
            model.removeContacts(ids: targets)
        }
        selection = document.model.contacts.first?.id
    }

    private func setAllPrintable(_ value: Bool) {
        document.update(undoManager: undoManager, actionName: "印刷対象を変更") { model in
            for index in model.contacts.indices where model.contacts[index].status != .mourning {
                model.contacts[index].isPrintable = value
            }
        }
    }

    private func clearMourning() {
        document.update(undoManager: undoManager, actionName: "喪中を除外") { model in
            for index in model.contacts.indices where model.contacts[index].status == .mourning {
                model.contacts[index].isPrintable = false
            }
        }
    }
}

struct StatusBadge: View {
    var status: SendStatus
    var contact: Contact

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(contact.isPrintable || status == .mourning ? status.label : "対象外")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch status {
        case .planned: contact.isPrintable ? .green : .gray
        case .sent: .blue
        case .received: .teal
        case .mourning: .purple
        case .skip: .gray
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
