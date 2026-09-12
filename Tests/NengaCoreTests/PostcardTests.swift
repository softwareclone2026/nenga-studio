import Testing
import Foundation
@testable import NengaCore

@Suite("はがきの規格と印刷設定")
struct PostcardTests {
    @Test("はがきの寸法は 100×148mm")
    func paper() {
        let paper = PostcardPaper.standard
        #expect(paper.widthMM == 148)
        #expect(paper.heightMM == 100)
        #expect(paper.kind == .official)
    }

    @Test("郵便番号枠は 7 枠で、はがきの内側に収まる")
    func postalFrame() {
        let spec = PostalCodeFrameSpec()
        #expect(spec.boxCount == 7)
        #expect(abs(spec.totalWidthMM - spec.boxWidthMM * 7) < 0.0001)
        let frame = spec.frameRect()
        #expect(frame.minX >= 0)
        #expect(frame.maxX <= 148)
        #expect(frame.minY >= 0)
        #expect(frame.maxY <= 100)
    }

    @Test("数字は各枠の中央に入る")
    func digitPlacement() {
        let spec = PostalCodeFrameSpec()
        let positions = spec.digitPositions(for: "1500001")
        #expect(positions.count == 7)
        #expect(positions.map(\.character) == ["1", "5", "0", "0", "0", "0", "1"])
        for (index, entry) in positions.enumerated() {
            let box = spec.boxRect(index: index)
            #expect(abs(entry.rect.midX - box.midX) < 0.001)
            #expect(abs(entry.rect.midY - box.midY) < 0.001)
        }
    }

    @Test("7 桁に満たない郵便番号は左詰めで空欄が残る")
    func shortPostalCode() {
        let spec = PostalCodeFrameSpec()
        let positions = spec.digitPositions(for: "150")
        #expect(positions[0].character == "1")
        #expect(positions[2].character == "0")
        #expect(positions[3].character.isEmpty)
    }

    @Test("用紙の向きでページサイズが変わる")
    func pageSize() {
        var document = NengaDocument(year: 2027)
        document.printRotation = .clockwise
        #expect(PostcardExport.pageSizeMM(document) == CGSize(width: 100, height: 148))
        document.printRotation = .none
        #expect(PostcardExport.pageSizeMM(document) == CGSize(width: 148, height: 100))
        document.printRotation = .counterClockwise
        #expect(PostcardExport.pageSizeMM(document) == CGSize(width: 100, height: 148))
    }

    @Test("印刷対象の絞り込み")
    func printableFilter() {
        let contacts = [
            Contact(familyName: "送る", status: .planned),
            Contact(familyName: "喪中", status: .mourning),
            Contact(familyName: "除外", status: .planned, isPrintable: false),
            Contact(familyName: "受領", status: .received),
        ]
        let printable = contacts.printable()
        #expect(printable.map(\.familyName) == ["送る"])
        let withReceived = contacts.printable(includeReceived: true)
        #expect(withReceived.count == 2)
        #expect(!withReceived.contains { $0.familyName == "喪中" })
    }
}
