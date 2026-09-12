import Testing
import Foundation
@testable import NengaCore

@Suite("住所と郵便番号の整形")
struct AddressTests {
    @Test("郵便番号を 7 桁に正規化する")
    func normalizePostalCode() {
        #expect(AddressFormatter.normalizePostalCode("150-0001") == "1500001")
        #expect(AddressFormatter.normalizePostalCode("〒1500001") == "1500001")
        #expect(AddressFormatter.normalizePostalCode("１５０−０００１") == "1500001")
        #expect(AddressFormatter.normalizePostalCode("150") == nil)
    }

    @Test("郵便番号の表示形式")
    func formattedPostalCode() {
        #expect(AddressFormatter.formattedPostalCode("1500001") == "150-0001")
        #expect(AddressFormatter.formattedPostalCode("2200011") == "220-0011")
    }

    @Test("住所から都道府県を切り出す")
    func splitAddress() {
        let split = AddressFormatter.split(address: "東京都渋谷区神宮前1-2-3")
        #expect(split.prefecture == "東京都")
        #expect(split.rest == "渋谷区神宮前1-2-3")
        #expect(AddressFormatter.removingPrefecture(from: "北海道札幌市中央区北一条西2-4") == "札幌市中央区北一条西2-4")
    }

    @Test("番地を丁目・番・号に展開する")
    func expandChomeBanchi() {
        #expect(AddressFormatter.expandChomeBanchi("神宮前1-2-3") == "神宮前1丁目2番3号")
        #expect(AddressFormatter.expandChomeBanchi("北一条西2-4") == "北一条西2丁目4番")
        #expect(AddressFormatter.expandChomeBanchi("栄3-15-33 サンプルビル") == "栄3丁目15番33号 サンプルビル")
    }

    @Test("建物名を取り出す")
    func buildingName() {
        #expect(AddressFormatter.buildingName(from: "1-2-3 サンプルマンション101") == "サンプルマンション101")
    }

    @Test("氏名を姓と名に分割する")
    func splitFullName() {
        let split = AddressBookCSV.splitFullName("山田 太郎")
        #expect(split.family == "山田")
        #expect(split.given == "太郎")
        let noSpace = AddressBookCSV.splitFullName("山田太郎")
        #expect(noSpace.family == "山田")
        #expect(noSpace.given == "太郎")
    }
}
