import Foundation

/// 元号・干支・漢数字など、年賀状で使う和暦まわりの計算。
public enum JapaneseNumber {
    private static let kanjiDigits = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// 1〜99 程度の整数を漢数字に変換する（令和九年、二十五年など）。
    public static func kanji(_ value: Int) -> String {
        if value <= 0 { return "〇" }
        if value < 10 { return kanjiDigits[value] }
        if value < 20 { return value == 10 ? "十" : "十" + kanjiDigits[value - 10] }
        let tens = value / 10
        let ones = value % 10
        var text = kanjiDigits[tens] + "十"
        if ones > 0 { text += kanjiDigits[ones] }
        return text
    }
}

/// 十二支。2020 年（子年）を基準に算出する。
public enum Zodiac: Int, Codable, Sendable, CaseIterable {
    case ne = 0, ushi, tora, u, tatsu, mi, uma, hitsuji, saru, tori, inu, i

    public init(year: Int) {
        let index = ((year - 2020) % 12 + 12) % 12
        self = Zodiac(rawValue: index) ?? .ne
    }

    public var kanji: String {
        switch self {
        case .ne: "子"
        case .ushi: "丑"
        case .tora: "寅"
        case .u: "卯"
        case .tatsu: "辰"
        case .mi: "巳"
        case .uma: "午"
        case .hitsuji: "未"
        case .saru: "申"
        case .tori: "酉"
        case .inu: "戌"
        case .i: "亥"
        }
    }

    public var kana: String {
        switch self {
        case .ne: "ね"
        case .ushi: "うし"
        case .tora: "とら"
        case .u: "うさぎ"
        case .tatsu: "たつ"
        case .mi: "へび"
        case .uma: "うま"
        case .hitsuji: "ひつじ"
        case .saru: "さる"
        case .tori: "とり"
        case .inu: "いぬ"
        case .i: "いのしし"
        }
    }

    public var animal: String {
        switch self {
        case .ne: "ねずみ"
        case .ushi: "牛"
        case .tora: "虎"
        case .u: "うさぎ"
        case .tatsu: "龍"
        case .mi: "蛇"
        case .uma: "馬"
        case .hitsuji: "羊"
        case .saru: "猿"
        case .tori: "鶏"
        case .inu: "犬"
        case .i: "猪"
        }
    }
}

/// 年賀状が対象にしている年（2027 年用なら 2027）の情報。
public struct YearInfo: Codable, Sendable, Hashable {
    public var year: Int

    public init(year: Int) {
        self.year = year
    }

    public var zodiac: Zodiac { Zodiac(year: year) }

    /// 令和九年 のような和暦表記。
    public var wareki: String {
        if year >= 2019 {
            let n = year - 2018
            return n == 1 ? "令和元年" : "令和\(JapaneseNumber.kanji(n))年"
        }
        if year >= 1989 {
            let n = year - 1988
            return n == 1 ? "平成元年" : "平成\(JapaneseNumber.kanji(n))年"
        }
        return "\(year)年"
    }

    public var western: String { "\(year)年" }

    public var zodiacLabel: String { "\(zodiac.kanji)年（\(zodiac.kana)年）" }

    /// 前年の年（「昨年は…」の文面用）。
    public var previousYearInfo: YearInfo { YearInfo(year: year - 1) }
}
