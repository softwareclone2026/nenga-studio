import Foundation
import NengaCore
import SwiftUI
import UniformTypeIdentifiers

/// アプリとして壊れやすい部分（書類のファイル化・読み戻し・描画）をまとめて確認する。
/// GUI を介さずに `--self-check` で実行できる。
enum SelfCheck {
    @MainActor
    static func run() -> Int32 {
        var failures: [String] = []

        func check(_ name: String, _ condition: Bool, _ detail: String = "") {
            if condition {
                print("  OK  \(name)")
            } else {
                failures.append(name)
                print("  NG  \(name) \(detail)")
            }
        }

        print("自己診断")
        let workDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nenga-self-check-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        // 1. 書類のファイル化と読み戻し（DocumentGroup と同じ経路）
        var model = NengaDocument.sample(year: 2027)
        let project = NengaProjectDocument(model: model)
        let photo = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG のシグネチャだけ
        let assetName = project.addAsset(data: photo, fileName: "sample.png")
        model = project.model

        do {
            let wrapper = try NengaProjectDocument.makeFileWrapper(document: model, assets: project.assets)
            let packageURL = workDirectory.appendingPathComponent("check.nenga")
            try wrapper.write(to: packageURL, options: .atomic, originalContentsURL: nil)
            check("書類をパッケージとして書き出せる", FileManager.default.fileExists(atPath: packageURL.path))

            let reloaded = try NengaProjectDocument.load(from: FileWrapper(url: packageURL))
            check("書き出した書類を読み戻せる", reloaded.document.contacts.count == model.contacts.count)
            check("写真が保持される", reloaded.assets[assetName] != nil)
            check(
                "レイアウト設定が保持される",
                reloaded.document.addressLayout.postalCodeFrame.leftMM == model.addressLayout.postalCodeFrame.leftMM
            )
        } catch {
            check("書類のファイル化", false, "\(error)")
        }

        // 2. 描画（宛名面・文面・位置合わせ）
        for (name, page) in [
            ("宛名面", PostcardPage.address(model.contacts[0])),
            ("文面", PostcardPage.design(contact: model.contacts[0])),
            ("位置合わせシート", PostcardPage.calibration),
        ] {
            let data = try? PostcardExport.makePDF(document: model, pages: [page], mode: .print, assetLoader: project.imageLoader())
            check("\(name)の PDF を作れる", (data?.count ?? 0) > 1000)
        }

        // 3. 印刷対象の数
        check(
            "印刷対象の絞り込み",
            model.printableContacts.count == 5,
            "\(model.printableContacts.count) 件"
        )

        // 4. テンプレートがすべて描ける
        var templateFailures: [String] = []
        for template in NengaTemplates.all {
            var copy = model
            copy.design = template.make(copy.year)
            let image = PostcardExport.makeCGImage(document: copy, page: .design(contact: model.contacts[0]), dpi: 40)
            if image == nil { templateFailures.append(template.id) }
        }
        check("全テンプレートを描画できる", templateFailures.isEmpty, templateFailures.joined(separator: ","))

        if failures.isEmpty {
            print("すべて成功しました")
            return 0
        }
        FileHandle.standardError.write(Data("失敗: \(failures.joined(separator: ", "))\n".utf8))
        return 1
    }
}
