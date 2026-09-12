import Foundation

/// 文面にそのまま置ける賀詞・挨拶文の定型句。
public enum NengaGreetings {
    public struct Group: Sendable, Identifiable {
        public var id: String { title }
        public var title: String
        public var phrases: [String]

        public init(title: String, phrases: [String]) {
            self.title = title
            self.phrases = phrases
        }
    }

    public static let groups: [Group] = [
        Group(title: "賀詞（短い）", phrases: [
            "謹賀新年", "恭賀新年", "賀正", "迎春", "初春", "新春",
        ]),
        Group(title: "賀詞（丁寧）", phrases: [
            "あけましておめでとうございます",
            "新春のお慶びを申し上げます",
            "謹んで新年のお慶びを申し上げます",
            "明けましておめでとうございます",
            "Happy New Year",
        ]),
        Group(title: "添え書き", phrases: [
            "本年もよろしくお願い申し上げます",
            "今年もどうぞよろしくお願いいたします",
            "皆様のご多幸をお祈り申し上げます",
            "昨年はお世話になりました",
            "本年も変わらぬご愛顧のほど、よろしくお願い申し上げます",
        ]),
        Group(title: "喪中・寒中", phrases: [
            "喪中につき年末年始のご挨拶を失礼させていただきます",
            "寒中お見舞い申し上げます",
            "本年もお世話になりました",
        ]),
    ]

    public static var all: [String] {
        groups.flatMap(\.phrases)
    }
}
