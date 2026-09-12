import Foundation

/// 郵便番号・住所・敬称まわりの整形。CSV 取り込みや宛名面の描画から使う。
public enum AddressFormatter {
    private static let prefectures: [String] = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県",
        "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
        "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県",
        "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
    ]

    /// 全角数字・ハイフン・〒 を落として 7 桁に正規化する。7 桁でなければ nil。
    public static func normalizePostalCode(_ raw: String) -> String? {
        var digits = ""
        for character in raw where character.isNumber {
            if let value = character.wholeNumberValue {
                digits.append(String(value))
            }
        }
        guard digits.count >= 7 else { return nil }
        return String(digits.prefix(7))
    }

    /// 7 桁を 123-4567 形式にする。
    public static func formattedPostalCode(_ raw: String) -> String {
        guard let digits = normalizePostalCode(raw) else {
            return raw.trimmingCharacters(in: .whitespaces)
        }
        let head = digits.prefix(3)
        let tail = digits.suffix(4)
        return "\(head)-\(tail)"
    }

    /// 「東京都渋谷区神南1-2-3」→ ("東京都渋谷区", "神南1-2-3")
    public static func split(address: String) -> (prefecture: String, rest: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefecture in prefectures where trimmed.hasPrefix(prefecture) {
            let rest = String(trimmed.dropFirst(prefecture.count))
            return (prefecture, rest.trimmingCharacters(in: .whitespaces))
        }
        return ("", trimmed)
    }

    /// 住所文字列から都道府県を落とす。
    public static func removingPrefecture(from address: String) -> String {
        let (_, rest) = split(address: address)
        return rest
    }

    public static func prefecture(of address: String) -> String {
        split(address: address).prefecture
    }

    /// 番地を「1丁目2番3号」に展開する。年賀状ソフトの定番機能。
    /// 「神南1-2-3」→「神南1丁目2番3号」、「1-2」→「1丁目2番」。
    public static func expandChomeBanchi(_ text: String) -> String {
        let pattern = #"([0-9０-９]+)\s*[-ー−–—‐]\s*([0-9０-９]+)(?:\s*[-ー−–—‐]\s*([0-9０-９]+))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var result = text
        let matches = regex.matches(in: text, range: nsRange)
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text) else { continue }
            let first = groupText(match, at: 1, in: text)
            let second = groupText(match, at: 2, in: text)
            let third = groupText(match, at: 3, in: text)
            var replacement = "\(first)丁目\(second)番"
            if !third.isEmpty {
                replacement += "\(third)号"
            }
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    private static func groupText(_ match: NSTextCheckingResult, at index: Int, in text: String) -> String {
        guard index < match.numberOfRanges,
              let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
    }

    /// 建物名だけを取り出す（「1-2-3 ○○マンション101」→「○○マンション101」）。
    public static func buildingName(from address2: String) -> String {
        let pattern = #"^[0-9０-９\-ー−–—‐番地号丁目\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return "" }
        let nsRange = NSRange(address2.startIndex..<address2.endIndex, in: address2)
        guard let match = regex.firstMatch(in: address2, range: nsRange),
              let range = Range(match.range, in: address2) else { return "" }
        // 番地の部分を除いた残り（建物名）を返す
        return String(address2[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    /// 宛名面の氏名（敬称込み）を組み立てる。
    public static func recipientName(_ contact: Contact, honorific: Honorific? = nil) -> String {
        let suffix = (honorific ?? contact.honorific).rawValue
        return contact.fullName + suffix
    }
}
