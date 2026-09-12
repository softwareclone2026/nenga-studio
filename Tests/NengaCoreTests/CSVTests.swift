import Testing
import Foundation
@testable import NengaCore

@Suite("住所録 CSV")
struct CSVTests {
    @Test("見出し行のある CSV を取り込む")
    func importWithHeader() throws {
        let csv = """
        氏名,郵便番号,住所1,住所2,電話番号,年賀状,連名,グループ
        山田 太郎,150-0001,東京都渋谷区,神宮前1-2-3,03-1111-2222,送る予定,花子・一郎,友人
        鈴木 花子,2200011,神奈川県横浜市西区,高島2-18-1,045-333-4444,喪中,,親戚
        """
        let result = try AddressBookCSV.importContacts(from: Data(csv.utf8))
        #expect(result.usedHeaderRow)
        #expect(result.contacts.count == 2)
        let yamada = result.contacts[0]
        #expect(yamada.familyName == "山田")
        #expect(yamada.givenName == "太郎")
        #expect(yamada.postalCode == "1500001")
        #expect(yamada.address1 == "東京都渋谷区")
        #expect(yamada.group == "友人")
        #expect(yamada.coRecipients.map(\.name) == ["花子", "一郎"])
        #expect(result.contacts[1].status == .mourning)
    }

    @Test("見出し行の表記ゆれを吸収する")
    func headerAliases() throws {
        let csv = """
        〒,住所,名前,メールアドレス,TEL
        100-0001,東京都千代田区千代田1-1,年賀 太郎,taro@example.jp,03-9999-0000
        """
        let result = try AddressBookCSV.importContacts(from: Data(csv.utf8))
        #expect(result.contacts.count == 1)
        #expect(result.contacts[0].postalCode == "1000001")
        #expect(result.contacts[0].email == "taro@example.jp")
        #expect(result.contacts[0].phone == "03-9999-0000")
    }

    @Test("見出しが無い CSV は既定の並びとして読む")
    func importWithoutHeader() throws {
        let csv = """
        佐藤 健一,460-0008,愛知県名古屋市中区,栄3-15-33,052-555-6666
        """
        let result = try AddressBookCSV.importContacts(from: Data(csv.utf8))
        #expect(!result.usedHeaderRow)
        #expect(result.contacts.first?.familyName == "佐藤")
        #expect(result.contacts.first?.postalCode == "4600008")
    }

    @Test("Shift-JIS の CSV を判別して読む")
    func shiftJIS() throws {
        let text = "氏名,郵便番号,住所1,住所2\n高橋 美咲,530-0001,大阪府大阪市北区,梅田1-1-3"
        let data = try #require(text.data(using: .shiftJIS))
        let result = try AddressBookCSV.importContacts(from: data)
        #expect(result.detectedEncoding == "Shift-JIS")
        #expect(result.contacts.first?.familyName == "高橋")
    }

    @Test("書き出して読み直しても内容が変わらない")
    func roundTrip() throws {
        let contacts = SampleContacts.make()
        for encoding in AddressBookCSV.TextEncoding.allCases {
            let data = AddressBookCSV.exportData(contacts: contacts, encoding: encoding)
            let result = try AddressBookCSV.importContacts(from: data)
            #expect(result.contacts.count == contacts.count)
            #expect(result.contacts.first?.postalCode == contacts.first?.postalCode)
            #expect(result.contacts.first?.fullName == contacts.first?.fullName)
            #expect(result.contacts[5].coRecipients.count == 3)
        }
    }

    @Test("引用符付きのフィールドを扱える")
    func quotedField() throws {
        let csv = "氏名,郵便番号,住所1,住所2,備考\n\"伊藤 由紀\",8100001,福岡県福岡市中央区,\"天神2-5-19, 5F\",\"メモ, カンマ入り\""
        let result = try AddressBookCSV.importContacts(from: Data(csv.utf8))
        #expect(result.contacts.first?.address2 == "天神2-5-19, 5F")
        #expect(result.contacts.first?.note == "メモ, カンマ入り")
    }
}
