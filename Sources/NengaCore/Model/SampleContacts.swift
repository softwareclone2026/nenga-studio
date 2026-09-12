import Foundation

/// 動作確認と初回起動時に使うサンプル住所録。
public enum SampleContacts {
    public static func make() -> [Contact] {
        [
            Contact(
                familyName: "山田",
                givenName: "太郎",
                postalCode: "1500001",
                address1: "東京都渋谷区",
                address2: "神宮前1-2-3 サンプルマンション101",
                phone: "03-1111-2222",
                email: "yamada@example.jp",
                group: "友人",
                status: .planned
            ),
            Contact(
                familyName: "鈴木",
                givenName: "花子",
                postalCode: "2200011",
                address1: "神奈川県横浜市西区",
                address2: "高島2-18-1",
                phone: "045-333-4444",
                group: "友人",
                status: .received,
                coRecipients: [CoRecipient(name: "一郎")]
            ),
            Contact(
                familyName: "佐藤",
                givenName: "健一",
                honorific: .sensei,
                company: "株式会社サンプル",
                department: "営業部",
                postalCode: "4600008",
                address1: "愛知県名古屋市中区",
                address2: "栄3-15-33 サンプルビル 8F",
                phone: "052-555-6666",
                group: "仕事",
                status: .planned
            ),
            Contact(
                familyName: "高橋",
                givenName: "美咲",
                postalCode: "5300001",
                address1: "大阪府大阪市北区",
                address2: "梅田1-1-3 梅田サンプルタワー 21F",
                phone: "06-7777-8888",
                group: "親戚",
                status: .planned
            ),
            Contact(
                familyName: "田中",
                givenName: "誠",
                postalCode: "0600001",
                address1: "北海道札幌市中央区",
                address2: "北一条西2-4",
                phone: "011-222-3333",
                group: "親戚",
                status: .mourning,
                note: "喪中のため年賀状は送らない（寒中見舞いを送る）"
            ),
            Contact(
                familyName: "伊藤",
                givenName: "由紀",
                postalCode: "8100001",
                address1: "福岡県福岡市中央区",
                address2: "天神2-5-19 天神サンプルビル 5F",
                phone: "092-444-5555",
                email: "ito@example.jp",
                group: "仕事",
                status: .planned,
                coRecipients: [
                    CoRecipient(name: "健"),
                    CoRecipient(name: "葵"),
                    CoRecipient(name: "光"),
                ]
            ),
            Contact(
                familyName: "渡辺",
                givenName: "浩",
                postalCode: "9800811",
                address1: "宮城県仙台市青葉区",
                address2: "一番町4-6-1",
                phone: "022-666-7777",
                group: "友人",
                status: .planned
            ),
            Contact(
                familyName: "中村",
                givenName: "あゆみ",
                postalCode: "6008216",
                address1: "京都府京都市下京区",
                address2: "東塩小路町721-1",
                phone: "075-888-9999",
                group: "友人",
                status: .skip,
                note: "今年は欠礼"
            ),
        ]
    }
}
