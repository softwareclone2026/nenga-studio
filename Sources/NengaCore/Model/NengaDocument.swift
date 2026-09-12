import Foundation

/// 差出人（自分）の情報。宛名面の左下などに印刷する。
public struct SenderProfile: Codable, Sendable, Hashable {
    public var familyName: String
    public var givenName: String
    public var postalCode: String
    public var address1: String
    public var address2: String
    public var phone: String
    public var email: String
    public var note: String

    public init(
        familyName: String = "",
        givenName: String = "",
        postalCode: String = "",
        address1: String = "",
        address2: String = "",
        phone: String = "",
        email: String = "",
        note: String = ""
    ) {
        self.familyName = familyName
        self.givenName = givenName
        self.postalCode = postalCode
        self.address1 = address1
        self.address2 = address2
        self.phone = phone
        self.email = email
        self.note = note
    }

    public var fullName: String { familyName + givenName }
    public var fullAddress: String { address1 + address2 }
    public var isEmpty: Bool { fullName.isEmpty && fullAddress.isEmpty }
}

public enum HonorificPlacement: String, Codable, Sendable, CaseIterable {
    case each
    case lastOnly
    case none

    public var label: String {
        switch self {
        case .each: "全員に付ける"
        case .lastOnly: "最後の 1 名だけ"
        case .none: "付けない"
        }
    }
}

public enum CoRecipientLayout: String, Codable, Sendable, CaseIterable {
    case newColumn
    case sameLine

    public var label: String {
        switch self {
        case .newColumn: "別の行に書く"
        case .sameLine: "・で並べる"
        }
    }
}

/// 宛名面（表面）のレイアウト設定。
public struct AddressLayout: Codable, Sendable, Hashable {
    public var paper: PostcardPaper
    public var postalCodeFrame: PostalCodeFrameSpec
    public var direction: TextDirection
    public var addressFont: FontChoice
    public var nameFont: FontChoice
    public var addressSizeMM: Double
    public var nameSizeMM: Double
    public var companySizeMM: Double
    public var honorificPlacement: HonorificPlacement
    public var coRecipientLayout: CoRecipientLayout
    public var coRecipientScale: Double
    public var showCompany: Bool
    public var omitPrefecture: Bool
    public var convertChomeBanchi: Bool
    public var sender: SenderLayout
    /// プリンタごとの位置ずれ補正（mm）
    public var offsetXMM: Double
    public var offsetYMM: Double
    public var showsGuides: Bool

    public init(
        paper: PostcardPaper = .standard,
        postalCodeFrame: PostalCodeFrameSpec = PostalCodeFrameSpec(),
        direction: TextDirection = .vertical,
        addressFont: FontChoice = .mincho,
        nameFont: FontChoice = .mincho,
        addressSizeMM: Double = 3.4,
        nameSizeMM: Double = 5.0,
        companySizeMM: Double = 3.0,
        honorificPlacement: HonorificPlacement = .each,
        coRecipientLayout: CoRecipientLayout = .newColumn,
        coRecipientScale: Double = 0.8,
        showCompany: Bool = false,
        omitPrefecture: Bool = false,
        convertChomeBanchi: Bool = true,
        sender: SenderLayout = SenderLayout(),
        offsetXMM: Double = 0,
        offsetYMM: Double = 0,
        showsGuides: Bool = false
    ) {
        self.paper = paper
        self.postalCodeFrame = postalCodeFrame
        self.direction = direction
        self.addressFont = addressFont
        self.nameFont = nameFont
        self.addressSizeMM = addressSizeMM
        self.nameSizeMM = nameSizeMM
        self.companySizeMM = companySizeMM
        self.honorificPlacement = honorificPlacement
        self.coRecipientLayout = coRecipientLayout
        self.coRecipientScale = coRecipientScale
        self.showCompany = showCompany
        self.omitPrefecture = omitPrefecture
        self.convertChomeBanchi = convertChomeBanchi
        self.sender = sender
        self.offsetXMM = offsetXMM
        self.offsetYMM = offsetYMM
        self.showsGuides = showsGuides
    }
}

/// 差出人欄の設定。
public struct SenderLayout: Codable, Sendable, Hashable {
    public enum Corner: String, Codable, Sendable, CaseIterable {
        case bottomLeft
        case bottomRight

        public var label: String { self == .bottomLeft ? "左下" : "右下" }
    }

    public var isEnabled: Bool
    public var corner: Corner
    public var direction: TextDirection
    public var sizeMM: Double
    public var showsPostalCode: Bool
    public var showsPhone: Bool
    public var showsEmail: Bool
    public var marginMM: Double

    public init(
        isEnabled: Bool = true,
        corner: Corner = .bottomLeft,
        direction: TextDirection = .vertical,
        sizeMM: Double = 2.4,
        showsPostalCode: Bool = true,
        showsPhone: Bool = true,
        showsEmail: Bool = false,
        marginMM: Double = 8.0
    ) {
        self.isEnabled = isEnabled
        self.corner = corner
        self.direction = direction
        self.sizeMM = sizeMM
        self.showsPostalCode = showsPostalCode
        self.showsPhone = showsPhone
        self.showsEmail = showsEmail
        self.marginMM = marginMM
    }
}

/// 印刷時の内容の回転。プリンタの給紙方向に合わせて選ぶ。
/// はがきは短辺 100mm を幅にして縦送りされることが多いため、既定は 90 度。
public enum PrintRotation: Int, Codable, Sendable, CaseIterable {
    /// 横送り（148×100mm のまま）
    case none = 0
    /// 縦送り（100×148mm に時計回りで 90 度回す）— 標準
    case clockwise = 90
    /// 横送り・逆さま
    case upsideDown = 180
    /// 縦送り（反時計回りに 90 度回す）
    case counterClockwise = 270

    public var label: String {
        switch self {
        case .none: "横送り（回転なし）"
        case .clockwise: "縦送り（時計回り 90 度）"
        case .upsideDown: "横送り（180 度回転）"
        case .counterClockwise: "縦送り（反時計回り 90 度）"
        }
    }

    public var isPortraitFeed: Bool {
        self == .clockwise || self == .counterClockwise
    }
}

/// 年賀状 1 冊分のプロジェクト。住所録と文面をまとめて 1 ファイルにする。
public struct NengaDocument: Codable, Sendable, Hashable {
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var year: Int
    public var sender: SenderProfile
    public var contacts: [Contact]
    public var design: DesignPage
    public var addressLayout: AddressLayout
    public var printRotation: PrintRotation
    /// パッケージ内 assets/ に置いた画像ファイル名
    public var assetFileNames: [String]

    public init(
        formatVersion: Int = NengaDocument.currentFormatVersion,
        year: Int = 2027,
        sender: SenderProfile = SenderProfile(),
        contacts: [Contact] = [],
        design: DesignPage = DesignPage(),
        addressLayout: AddressLayout = AddressLayout(),
        printRotation: PrintRotation = .clockwise,
        assetFileNames: [String] = []
    ) {
        self.formatVersion = formatVersion
        self.year = year
        self.sender = sender
        self.contacts = contacts
        self.design = design
        self.addressLayout = addressLayout
        self.printRotation = printRotation
        self.assetFileNames = assetFileNames
    }

    public var yearInfo: YearInfo { YearInfo(year: year) }

    public var paper: PostcardPaper { addressLayout.paper }

    public var printableContacts: [Contact] { contacts.printable() }

    public mutating func replace(contact: Contact) {
        guard let index = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[index] = contact
    }

    public mutating func removeContacts(ids: Set<UUID>) {
        contacts.removeAll { ids.contains($0.id) }
    }

    public static func sample(year: Int = 2027) -> NengaDocument {
        var document = NengaDocument(year: year)
        document.sender = SenderProfile(
            familyName: "年賀",
            givenName: "太郎",
            postalCode: "1000001",
            address1: "東京都千代田区",
            address2: "千代田1-1-1 サンプルビル 10F",
            phone: "03-1234-5678",
            email: "nenga@example.jp"
        )
        document.contacts = SampleContacts.make()
        document.design = NengaTemplates.template(id: NengaTemplates.defaultTemplateID, year: year) ?? DesignPage()
        return document
    }
}
