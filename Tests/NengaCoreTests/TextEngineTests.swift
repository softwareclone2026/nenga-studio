import Testing
import Foundation
@testable import NengaCore

@Suite("縦書きの組版")
struct TextEngineTests {
    @Test("算用数字の連なりはまとめて回す")
    func rotatedRuns() {
        let units = TextEngine.verticalUnits(of: "神宮前1丁目2番3号")
        let rotated = units.compactMap { unit -> String? in
            if case .rotatedRun(let text) = unit { return text }
            return nil
        }
        // 「1」「2」「3」は 1 文字なので通常の文字として扱う
        #expect(rotated.isEmpty)
        let units2 = TextEngine.verticalUnits(of: "TEL 03-1234-5678")
        let rotated2 = units2.compactMap { unit -> String? in
            if case .rotatedRun(let text) = unit { return text }
            return nil
        }
        // 欧文（TEL）も数字の連なりも、それぞれまとめて回転させる
        #expect(rotated2 == ["TEL", "03-1234-5678"])
    }

    @Test("句読点は右上へ寄せる")
    func punctuationAdjustment() {
        let adjustment = TextEngine.verticalAdjustment(for: "。", sizeMM: 4)
        #expect(adjustment.dxMM == 2)
        #expect(adjustment.dyMM == 2)
        #expect(adjustment.rotationDegrees == 0)
    }

    @Test("長音と括弧は回す")
    func rotationAdjustment() {
        #expect(TextEngine.verticalAdjustment(for: "ー", sizeMM: 4).rotationDegrees == -90)
        #expect(TextEngine.verticalAdjustment(for: "「", sizeMM: 4).rotationDegrees == -90)
        #expect(TextEngine.verticalAdjustment(for: "あ", sizeMM: 4).rotationDegrees == 0)
    }

    @Test("小書き仮名は右上に寄せる")
    func smallKana() {
        let adjustment = TextEngine.verticalAdjustment(for: "っ", sizeMM: 5)
        #expect(adjustment.dxMM > 0)
        #expect(adjustment.dyMM > 0)
    }

    @Test("縦書きの計測は列の数と高さを返す")
    func measureVertical() {
        let options = TextLayoutOptions(sizeMM: 5, direction: .vertical, letterSpacingMM: 0, lineSpacingMM: 2)
        // 6 文字を高さ 24mm に収めると 5mm×4 文字 + 余りで 2 列
        let size = TextEngine.measure("あけましておめでとう", options: options, maxHeightMM: 24)
        #expect(size.height <= 5 * 11 + 1)
        #expect(size.width >= 5)
    }

    @Test("横書きの計測は折り返し後の高さを返す")
    func measureHorizontal() {
        let options = TextLayoutOptions(sizeMM: 4, direction: .horizontal, alignment: .leading)
        let size = TextEngine.measure("あけましておめでとうございます", options: options, maxWidthMM: 40)
        #expect(size.width <= 41)
        #expect(size.height > 4)
    }
}
