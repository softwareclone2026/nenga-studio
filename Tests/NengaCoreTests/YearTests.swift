import Testing
import Foundation
@testable import NengaCore

@Suite("干支と和暦")
struct YearTests {
    @Test("十二支の割り当て")
    func zodiac() {
        #expect(Zodiac(year: 2020) == .ne)
        #expect(Zodiac(year: 2024) == .tatsu)
        #expect(Zodiac(year: 2026) == .uma)
        #expect(Zodiac(year: 2027) == .hitsuji)
        #expect(Zodiac(year: 2028) == .saru)
        #expect(Zodiac(year: 2027).kanji == "未")
        #expect(Zodiac(year: 2026).kana == "うま")
    }

    @Test("和暦の表記")
    func wareki() {
        #expect(YearInfo(year: 2027).wareki == "令和九年")
        #expect(YearInfo(year: 2019).wareki == "令和元年")
        #expect(YearInfo(year: 2026).wareki == "令和八年")
    }

    @Test("漢数字")
    func kanjiNumbers() {
        #expect(JapaneseNumber.kanji(1) == "一")
        #expect(JapaneseNumber.kanji(9) == "九")
        #expect(JapaneseNumber.kanji(10) == "十")
        #expect(JapaneseNumber.kanji(11) == "十一")
        #expect(JapaneseNumber.kanji(20) == "二十")
        #expect(JapaneseNumber.kanji(25) == "二十五")
    }
}
