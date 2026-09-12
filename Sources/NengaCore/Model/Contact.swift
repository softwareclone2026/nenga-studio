import Foundation

public enum Honorific: String, Codable, Sendable, CaseIterable, Hashable {
    case sama = "様"
    case sensei = "先生"
    case dono = "殿"
    case onchu = "御中"
    case kun = "君"
    case none = ""

    public var label: String {
        switch self {
        case .sama: "様"
        case .sensei: "先生"
        case .dono: "殿"
        case .onchu: "御中"
        case .kun: "君"
        case .none: "付けない"
        }
    }
}

/// 年賀状のやり取り状況。印刷対象の絞り込みに使う。
public enum SendStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case planned
    case sent
    case received
    case mourning
    case skip

    public var label: String {
        switch self {
        case .planned: "送る予定"
        case .sent: "送付済み"
        case .received: "受領済み"
        case .mourning: "喪中"
        case .skip: "送らない"
        }
    }

    /// 既定の印刷対象に含めるか。
    public var isDefaultPrintable: Bool {
        switch self {
        case .planned, .sent: true
        case .received, .mourning, .skip: false
        }
    }
}

/// 連名（ご家族・ご夫婦など）。
public struct CoRecipient: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var honorific: Honorific

    public init(id: UUID = UUID(), name: String = "", honorific: Honorific = .sama) {
        self.id = id
        self.name = name
        self.honorific = honorific
    }
}

/// 住所録 1 件分。
public struct Contact: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var familyName: String
    public var givenName: String
    public var honorific: Honorific
    public var company: String
    public var department: String
    public var postalCode: String
    /// 都道府県・市区郡まで（例: 東京都渋谷区）
    public var address1: String
    /// 町名・番地・建物名（例: 神南1-2-3 サンプルビル101）
    public var address2: String
    public var phone: String
    public var email: String
    public var group: String
    public var status: SendStatus
    public var note: String
    public var coRecipients: [CoRecipient]
    /// 縦書き・横書きの個別指定（nil なら文書の既定に従う）
    public var verticalOverride: Bool?
    /// 印刷対象にするか（既定は status から決める）
    public var isPrintable: Bool

    public init(
        id: UUID = UUID(),
        familyName: String = "",
        givenName: String = "",
        honorific: Honorific = .sama,
        company: String = "",
        department: String = "",
        postalCode: String = "",
        address1: String = "",
        address2: String = "",
        phone: String = "",
        email: String = "",
        group: String = "",
        status: SendStatus = .planned,
        note: String = "",
        coRecipients: [CoRecipient] = [],
        verticalOverride: Bool? = nil,
        isPrintable: Bool = true
    ) {
        self.id = id
        self.familyName = familyName
        self.givenName = givenName
        self.honorific = honorific
        self.company = company
        self.department = department
        self.postalCode = postalCode
        self.address1 = address1
        self.address2 = address2
        self.phone = phone
        self.email = email
        self.group = group
        self.status = status
        self.note = note
        self.coRecipients = coRecipients
        self.verticalOverride = verticalOverride
        self.isPrintable = isPrintable
    }

    public var fullName: String {
        let name = "\(familyName)\(givenName)"
        return name.isEmpty ? givenName : name
    }

    /// スペース入りの表示用氏名（一覧などで使う）。
    public var displayName: String {
        if familyName.isEmpty { return givenName }
        if givenName.isEmpty { return familyName }
        return "\(familyName) \(givenName)"
    }

    public var fullAddress: String {
        [address1, address2]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined()
    }

    /// 都道府県を省いた住所（差出人や一覧の表示用）。
    public var addressWithoutPrefecture: String {
        AddressFormatter.removingPrefecture(from: fullAddress)
    }

    public var combinedRecipients: [String] {
        [fullName] + coRecipients.map(\.name).filter { !$0.isEmpty }
    }
}

extension Array where Element == Contact {
    public func printable(includeReceived: Bool = false) -> [Contact] {
        filter { contact in
            if contact.status == .mourning { return false }
            if contact.isPrintable == false { return false }
            if contact.status == .received {
                return includeReceived
            }
            return contact.status.isDefaultPrintable
        }
    }

    public func sortedByName() -> [Contact] {
        sorted { lhs, rhs in
            lhs.familyName.localizedStandardCompare(rhs.familyName) == .orderedAscending
        }
    }

    public func sortedByPostalCode() -> [Contact] {
        sorted { $0.postalCode < $1.postalCode }
    }

    public func groups() -> [String] {
        let names: [String] = self.map { $0.group }.filter { !$0.isEmpty }
        return Set(names).sorted()
    }
}
