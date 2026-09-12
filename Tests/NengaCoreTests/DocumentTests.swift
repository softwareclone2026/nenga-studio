import Testing
import Foundation
@testable import NengaCore

@Suite("プロジェクトファイルと書き出し")
struct DocumentTests {
    @Test("保存して読み直すと同じ内容になる")
    func roundTrip() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nenga-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        var document = NengaDocument.sample(year: 2027)
        document.sender.phone = "03-0000-1111"
        try DocumentStore.write(document, to: directory)
        let loaded = try DocumentStore.read(from: directory)
        #expect(loaded.year == document.year)
        #expect(loaded.contacts.count == document.contacts.count)
        #expect(loaded.sender.phone == "03-0000-1111")
        #expect(loaded.design.elements.count == document.design.elements.count)
        #expect(loaded.addressLayout.postalCodeFrame.leftMM == document.addressLayout.postalCodeFrame.leftMM)
    }

    @Test("PDF はページ数と用紙サイズが正しい")
    func pdfPages() throws {
        var document = NengaDocument.sample(year: 2027)
        document.printRotation = .clockwise
        let pages = document.printableContacts.prefix(3).map { PostcardPage.address($0) }
        let data = try PostcardExport.makePDF(document: document, pages: Array(pages), mode: .print)
        // PDF はバイナリを含むため、バイト列として数える
        let pageCount = data.countOccurrences(of: "/Type /Page") - data.countOccurrences(of: "/Type /Pages")
        #expect(pageCount == pages.count)
        // 100×148mm = 283.46 × 419.53pt
        #expect(data.countOccurrences(of: "283.46") >= 1)
        #expect(data.countOccurrences(of: "419.52") >= 1)
    }

    @Test("用紙が横向きなら PDF も横向きになる")
    func landscapePDF() throws {
        var document = NengaDocument.sample(year: 2027)
        document.printRotation = .none
        let data = try PostcardExport.makePDF(document: document, pages: [.calibration], mode: .print)
        #expect(data.countOccurrences(of: "419.52") >= 1)
        #expect(data.countOccurrences(of: "283.46") >= 1)
    }

    @Test("はがき 1 面の画像を書き出せる")
    func png() throws {
        let document = NengaDocument.sample(year: 2027)
        let data = try PostcardExport.makePNG(document: document, page: .design(contact: nil), dpi: 100)
        #expect(data.count > 1000)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }

    @Test("すべてのテンプレートが要素を持つ")
    func templates() {
        #expect(NengaTemplates.all.count >= 8)
        for template in NengaTemplates.all {
            let page = template.make(2027)
            #expect(!page.elements.isEmpty, "\(template.id) が空です")
            #expect(page.templateID == template.id)
        }
    }

    @Test("差し込みのプレースホルダを展開する")
    func placeholders() {
        let contact = Contact(
            familyName: "山田",
            givenName: "太郎",
            postalCode: "1500001",
            address1: "東京都渋谷区",
            address2: "神宮前1-2-3",
            coRecipients: [CoRecipient(name: "花子")]
        )
        let year = YearInfo(year: 2027)
        let text = Placeholder.expand("{氏名}様（{住所}）{連名} {年号}", contact: contact, yearInfo: year)
        #expect(text == "山田太郎様（東京都渋谷区神宮前1-2-3）花子 令和九年")
    }

    @Test("レイヤーの重ね順を入れ替えられる")
    func layerOrder() {
        var page = NengaTemplates.template(id: "simple-kaji", year: 2027)!
        let first = page.elements[0].id
        page.bringToFront(first)
        #expect(page.elements.last?.id == first)
        page.sendToBack(first)
        #expect(page.elements.first?.id == first)
        page.bringForward(first)
        #expect(page.elements[1].id == first)
    }
}

extension Data {
    /// バイト列に含まれる ASCII 文字列の出現回数。
    func countOccurrences(of needle: String) -> Int {
        let pattern = Array(needle.utf8)
        let bytes = [UInt8](self)
        guard !pattern.isEmpty, bytes.count >= pattern.count else { return 0 }
        var count = 0
        for index in 0...(bytes.count - pattern.count) where Array(bytes[index..<(index + pattern.count)]) == pattern {
            count += 1
        }
        return count
    }
}
