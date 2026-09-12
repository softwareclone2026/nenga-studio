import Foundation

/// 住所録の CSV 取り込み・書き出し。
/// 年賀状ソフト各社の共通フォーマットに近い並びを採用し、見出し名は
/// 表記ゆれを吸収して自動判定する。
public enum AddressBookCSV {
    public enum TextEncoding: String, Sendable, CaseIterable {
        case utf8
        case utf8WithBOM
        case shiftJIS

        public var label: String {
            switch self {
            case .utf8: "UTF-8"
            case .utf8WithBOM: "UTF-8（BOM 付き）"
            case .shiftJIS: "Shift-JIS（Windows 互換）"
            }
        }
    }

    public struct ImportResult: Sendable {
        public var contacts: [Contact]
        public var warnings: [String]
        public var detectedEncoding: String
        public var usedHeaderRow: Bool
    }

    public enum CSVError: Error, LocalizedError {
        case empty
        case undecodable

        public var errorDescription: String? {
            switch self {
            case .empty: "CSV にデータが入っていません。"
            case .undecodable: "文字コードを判別できませんでした（UTF-8 / Shift-JIS に対応）。"
            }
        }
    }

    public static let exportHeaders = [
        "氏名", "姓", "名", "敬称", "郵便番号", "住所1", "住所2",
        "会社名", "部署名", "電話番号", "メール", "グループ", "年賀状", "連名", "備考",
    ]

    // MARK: - 取り込み

    public static func importContacts(from data: Data) throws -> ImportResult {
        guard !data.isEmpty else { throw CSVError.empty }
        let (text, encodingName) = try decode(data)
        let table = CSVTable(text: text)
        guard !table.rows.isEmpty else { throw CSVError.empty }

        let header = table.rows[0].map { normalizeHeader($0) }
        let mapping = columnMapping(for: header)
        let usedHeader = mapping.values.contains { $0 != nil }
        let dataRows = usedHeader ? Array(table.rows.dropFirst()) : table.rows

        var warnings: [String] = []
        if !usedHeader {
            warnings.append("見出し行を判別できなかったため、氏名・郵便番号・住所1・住所2・電話番号の並びとして読み込みました。")
        }

        var contacts: [Contact] = []
        for (offset, row) in dataRows.enumerated() {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            let contact = makeContact(from: row, mapping: mapping, usedHeader: usedHeader)
            if contact.fullName.isEmpty && contact.fullAddress.isEmpty {
                warnings.append("\(offset + (usedHeader ? 2 : 1)) 行目は氏名も住所も空のため取り込みませんでした。")
                continue
            }
            contacts.append(contact)
        }
        return ImportResult(
            contacts: contacts,
            warnings: warnings,
            detectedEncoding: encodingName,
            usedHeaderRow: usedHeader
        )
    }

    public static func decode(_ data: Data) throws -> (text: String, encodingName: String) {
        if data.starts(with: [0xEF, 0xBB, 0xBF]),
           let text = String(data: data.dropFirst(3), encoding: .utf8) {
            return (text, "UTF-8 (BOM)")
        }
        if let text = String(data: data, encoding: .utf8) {
            return (text, "UTF-8")
        }
        if let text = String(data: data, encoding: .shiftJIS) {
            return (text, "Shift-JIS")
        }
        throw CSVError.undecodable
    }

    private static func makeContact(from row: [String], mapping: [Field: Int?], usedHeader: Bool) -> Contact {
        func value(_ field: Field) -> String {
            guard let index = mapping[field] ?? nil, index < row.count else { return "" }
            return row[index].trimmingCharacters(in: .whitespaces)
        }

        var contact = Contact()
        if usedHeader {
            contact.familyName = value(.family)
            contact.givenName = value(.given)
            let full = value(.full)
            if contact.familyName.isEmpty && contact.givenName.isEmpty && !full.isEmpty {
                let split = splitFullName(full)
                contact.familyName = split.family
                contact.givenName = split.given
            } else if !full.isEmpty && (contact.familyName + contact.givenName) != full {
                let split = splitFullName(full)
                if contact.familyName.isEmpty { contact.familyName = split.family }
                if contact.givenName.isEmpty { contact.givenName = split.given }
            }
            contact.honorific = parseHonorific(value(.honorific))
            contact.postalCode = AddressFormatter.normalizePostalCode(value(.postal)) ?? value(.postal)
            contact.address1 = value(.address1)
            contact.address2 = value(.address2)
            contact.company = value(.company)
            contact.department = value(.department)
            contact.phone = value(.phone)
            contact.email = value(.email)
            contact.group = value(.group)
            contact.status = parseStatus(value(.status))
            contact.note = value(.note)
            contact.coRecipients = parseCoRecipients(value(.coRecipients))
        } else {
            let columns = row.map { $0.trimmingCharacters(in: .whitespaces) }
            if columns.count > 0 {
                let split = splitFullName(columns[0])
                contact.familyName = split.family
                contact.givenName = split.given
            }
            if columns.count > 1 { contact.postalCode = AddressFormatter.normalizePostalCode(columns[1]) ?? columns[1] }
            if columns.count > 2 { contact.address1 = columns[2] }
            if columns.count > 3 { contact.address2 = columns[3] }
            if columns.count > 4 { contact.phone = columns[4] }
        }

        contact.postalCode = AddressFormatter.normalizePostalCode(contact.postalCode) ?? contact.postalCode
        if contact.address1.isEmpty && !contact.address2.isEmpty && !contact.postalCode.isEmpty {
            contact.address1 = contact.address2
            contact.address2 = ""
        }
        if contact.status == .planned && !contact.note.isEmpty {
            let note = contact.note
            if note.contains("喪") { contact.status = .mourning }
        }
        return contact
    }

    /// 「山田 太郎」「山田太郎」を姓・名に分割する。
    public static func splitFullName(_ full: String) -> (family: String, given: String) {
        let trimmed = full.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return ("", "") }
        if let spaceIndex = trimmed.firstIndex(where: { $0 == " " || $0 == "　" }) {
            let family = String(trimmed[trimmed.startIndex..<spaceIndex])
            let given = String(trimmed[trimmed.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)
            return (family, given)
        }
        // 区切りが無い場合は 2 文字を姓とみなす（日本人の氏名の慣例）
        if trimmed.count >= 3 {
            let family = String(trimmed.prefix(2))
            let given = String(trimmed.dropFirst(2))
            return (family, given)
        }
        return (trimmed, "")
    }

    private static func parseHonorific(_ text: String) -> Honorific {
        switch text {
        case "様", "さま", "さん": return .sama
        case "先生": return .sensei
        case "殿": return .dono
        case "御中": return .onchu
        case "君": return .kun
        case "なし", "無し", "付けない": return .none
        default: return .sama
        }
    }

    private static func parseStatus(_ text: String) -> SendStatus {
        let value = text.trimmingCharacters(in: .whitespaces)
        if value.isEmpty { return .planned }
        if value.contains("喪") || value.contains("欠礼") { return .mourning }
        if value.contains("受") || value.contains("もらっ") { return .received }
        if value.contains("済") || value.contains("送信") || value == "○" || value == "◯" { return .sent }
        if value.contains("×") || value.contains("送らない") || value.contains("除外") { return .skip }
        return .planned
    }

    private static func parseCoRecipients(_ text: String) -> [CoRecipient] {
        let separators = CharacterSet(charactersIn: "、・,，/／;；\n")
        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { CoRecipient(name: $0) }
    }

    // MARK: - 見出しの対応付け

    private enum Field: String, CaseIterable {
        case full, family, given, honorific, postal, address1, address2
        case company, department, phone, email, group, status, coRecipients, note

        var aliases: [String] {
            switch self {
            case .full: ["氏名", "名前", "お名前", "宛名", "姓名", "name", "氏名漢字"]
            case .family: ["姓", "名字", "姓漢字", "familyname", "lastname", "family"]
            case .given: ["名", "下の名前", "名漢字", "givenname", "firstname", "given"]
            case .honorific: ["敬称", "敬称様等", "honorific"]
            case .postal: ["郵便番号", "〒", "郵便", "zip", "zipcode", "postalcode", "郵便番号数字"]
            case .address1: ["住所1", "住所１", "住所", "address1", "都道府県市区郡"]
            case .address2: ["住所2", "住所２", "番地", "建物名", "住所3", "address2", "町名番地"]
            case .company: ["会社名", "法人名", "会社", "company", "勤務先"]
            case .department: ["部署名", "部署", "役職", "department"]
            case .phone: ["電話番号", "電話", "tel", "phone", "携帯"]
            case .email: ["メール", "メールアドレス", "mail", "email", "e-mail"]
            case .group: ["グループ", "分類", "カテゴリ", "group", "種別"]
            case .status: ["年賀状", "状況", "状態", "ステータス", "status", "出欠"]
            case .coRecipients: ["連名", "ご家族", "家族", "correcipients"]
            case .note: ["備考", "メモ", "note", "memo", "摘要"]
            }
        }
    }

    private static func normalizeHeader(_ text: String) -> String {
        let fullWidthMap: [Character: Character] = [
            "０": "0", "１": "1", "２": "2", "３": "3", "４": "4",
            "５": "5", "６": "6", "７": "7", "８": "8", "９": "9",
        ]
        var result = ""
        for character in text.lowercased() {
            let mapped = fullWidthMap[character] ?? character
            if mapped == " " || mapped == "　" || mapped == "(" || mapped == ")" || mapped == "（" || mapped == "）" {
                continue
            }
            result.append(mapped)
        }
        return result
    }

    private static func columnMapping(for header: [String]) -> [Field: Int?] {
        var mapping: [Field: Int?] = [:]
        var used = Set<Int>()
        for field in Field.allCases {
            var found: Int?
            for (index, column) in header.enumerated() where !used.contains(index) {
                if field.aliases.contains(where: { normalizeHeader($0) == column }) {
                    found = index
                    break
                }
            }
            if found == nil {
                for (index, column) in header.enumerated() where !used.contains(index) && !column.isEmpty {
                    // 1 文字の別名（「名」「姓」）は部分一致だと誤検出するため使わない
                    if field.aliases.contains(where: { alias in
                        let normalized = normalizeHeader(alias)
                        return normalized.count >= 2 && column.contains(normalized)
                    }) {
                        found = index
                        break
                    }
                }
            }
            if let found {
                used.insert(found)
                mapping[field] = found
            } else {
                mapping[field] = nil
            }
        }
        return mapping
    }

    // MARK: - 書き出し

    public static func exportData(contacts: [Contact], encoding: TextEncoding = .utf8WithBOM) -> Data {
        let rows: [[String]] = [exportHeaders] + contacts.map { contact in
            [
                contact.fullName,
                contact.familyName,
                contact.givenName,
                contact.honorific.rawValue,
                AddressFormatter.formattedPostalCode(contact.postalCode),
                contact.address1,
                contact.address2,
                contact.company,
                contact.department,
                contact.phone,
                contact.email,
                contact.group,
                contact.status.label,
                contact.coRecipients.map(\.name).joined(separator: "・"),
                contact.note,
            ]
        }
        let text = CSVTable(rows: rows).text()
        switch encoding {
        case .utf8:
            return Data(text.utf8)
        case .utf8WithBOM:
            var data = Data([0xEF, 0xBB, 0xBF])
            data.append(Data(text.utf8))
            return data
        case .shiftJIS:
            var data = Data()
            let chunks = text.components(separatedBy: "\r\n")
            for (index, chunk) in chunks.enumerated() {
                let suffix = index == chunks.count - 1 ? "" : "\r\n"
                if let encoded = (chunk + suffix).data(using: .shiftJIS) {
                    data.append(encoded)
                } else if let fallback = (chunk + suffix).data(using: .shiftJIS, allowLossyConversion: true) {
                    data.append(fallback)
                }
            }
            return data
        }
    }
}
