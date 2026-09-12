import Foundation
import NengaCore

/// ヘッドレスで見本を書き出す。PDF と PNG を目で確認するために使う。
enum RenderSamples {
    static func run(outputDirectory: String) -> Int32 {
        let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("出力先を作成できません: \(error)\n".utf8))
            return 1
        }

        var document = NengaDocument.sample(year: 2027)
        let contacts = document.printableContacts

        do {
            // 宛名面（1 枚 1 ページの PDF と、確認用 PNG）
            let addressPages = contacts.map { PostcardPage.address($0) }
            try PostcardExport.writePDF(
                document: document,
                pages: addressPages,
                to: directory.appendingPathComponent("address-print.pdf")
            )
            for contact in contacts.prefix(5) {
                let data = try PostcardExport.makePNG(document: document, page: .address(contact), dpi: 240)
                try data.write(to: directory.appendingPathComponent("address-\(contact.familyName).png"))
            }

            // 文面（テンプレートごとに 1 ページ）
            var designPages: [PostcardPage] = []
            for template in NengaTemplates.all {
                guard let page = NengaTemplates.template(id: template.id, year: document.year) else { continue }
                document.design = page
                designPages.append(.design(contact: contacts.first))
                let data = try PostcardExport.makePNG(
                    document: document,
                    page: .design(contact: contacts.first),
                    dpi: 240
                )
                try data.write(to: directory.appendingPathComponent("design-\(template.id).png"))
                try PostcardExport.writePDF(
                    document: document,
                    pages: [.design(contact: contacts.first)],
                    to: directory.appendingPathComponent("design-\(template.id).pdf")
                )
            }
            document.design = NengaTemplates.template(id: NengaTemplates.defaultTemplateID, year: document.year) ?? document.design
            try PostcardExport.writePDF(
                document: document,
                pages: designPages,
                to: directory.appendingPathComponent("design-all.pdf")
            )

            // 位置合わせシート
            try PostcardExport.writePDF(
                document: document,
                pages: [.calibration],
                to: directory.appendingPathComponent("calibration.pdf")
            )
            let calibrationPNG = try PostcardExport.makePNG(document: document, page: .calibration, dpi: 200)
            try calibrationPNG.write(to: directory.appendingPathComponent("calibration.png"))

            // サンプルのプロジェクトファイル
            try DocumentStore.write(document, to: directory.appendingPathComponent("sample.nenga"))

            // CSV の見本
            let csv = AddressBookCSV.exportData(contacts: document.contacts, encoding: .shiftJIS)
            try csv.write(to: directory.appendingPathComponent("address-book.csv"))

            print("出力しました: \(directory.path)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("書き出しに失敗: \(error)\n".utf8))
            return 1
        }
    }

    static func writeSampleDocument(to path: String) -> Int32 {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
            let document = NengaDocument.sample(year: 2027)
            try DocumentStore.write(document, to: url)
            print("作成しました: \(url.path)")
            return 0
        } catch {
            FileHandle.standardError.write(Data("作成に失敗: \(error)\n".utf8))
            return 1
        }
    }

    /// 保存された .nenga の中身を確認する（動作チェック用）。
    static func inspect(path: String) -> Int32 {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        do {
            let document = try DocumentStore.read(from: url)
            print("""
            ファイル: \(url.lastPathComponent)
              年: \(document.year)（\(document.yearInfo.wareki)・\(document.yearInfo.zodiacLabel)）
              住所録: \(document.contacts.count) 件（印刷対象 \(document.printableContacts.count) 件）
              文面: \(document.design.elements.count) 要素・テンプレート \(document.design.templateID ?? "なし")
              差出人: \(document.sender.fullName.isEmpty ? "未設定" : document.sender.fullName)
              写真: \(document.assetFileNames.count) 点
              用紙の向き: \(document.printRotation.label)
            """)
            for contact in document.contacts.prefix(3) {
                print("  ・\(contact.displayName) 〒\(AddressFormatter.formattedPostalCode(contact.postalCode)) \(contact.status.label)")
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("読み込みに失敗: \(error)\n".utf8))
            return 1
        }
    }
}
