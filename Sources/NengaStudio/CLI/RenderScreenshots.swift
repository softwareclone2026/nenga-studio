import AppKit
import NengaCore
import SwiftUI

/// SwiftUI の画面をヘッドレスで画像化する。README 用のスクリーンショット作成と、
/// 画面崩れの確認に使う。
enum RenderScreenshots {
    @MainActor
    static func run(outputDirectory: String) -> Int32 {
        let directory = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("出力先を作成できません: \(error)\n".utf8))
            return 1
        }
        _ = NSApplication.shared

        let model = NengaDocument.sample(year: 2027)
        let document = NengaProjectDocument(model: model)

        let cases: [(String, AnyView)] = [
            ("window", AnyView(ContentView(document: document).frame(width: 1180, height: 760))),
            ("address-book", AnyView(AddressBookPane(
                document: document,
                selection: .constant(model.contacts.first?.id),
                onImportCSV: {},
                onExportCSV: {},
                onAddSample: {}
            ).frame(width: 1180, height: 700))),
            ("design", AnyView(DesignPane(
                document: document,
                selectedElementID: .constant(nil),
                previewContactID: .constant(model.contacts.first?.id)
            ).frame(width: 1180, height: 700))),
            ("printing", AnyView(PrintPane(
                document: document,
                previewContactID: .constant(model.contacts.first?.id),
                onPrint: {},
                onExportPDF: {},
                onPrintCalibration: {}
            ).frame(width: 1180, height: 700))),
            ("settings", AnyView(SettingsPane(document: document).frame(width: 1000, height: 700))),
        ]

        var failures: [String] = []
        for (name, view) in cases {
            guard let png = render(view: view, size: CGSize(width: 1180, height: 760)) else {
                failures.append(name)
                continue
            }
            do {
                try png.write(to: directory.appendingPathComponent("ui-\(name).png"))
            } catch {
                failures.append(name)
            }
        }

        if failures.isEmpty {
            print("画面画像を出力しました: \(directory.path)")
            return 0
        }
        FileHandle.standardError.write(Data("次の画面の画像化に失敗: \(failures.joined(separator: ", "))\n".utf8))
        return 1
    }

    /// NSHostingView をオフスクリーンで描き出す（ImageRenderer より複雑な画面に強い）。
    @MainActor
    private static func render(view: some View, size: CGSize) -> Data? {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: CGRect(origin: CGPoint(x: -20000, y: -20000), size: size),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        hosting.layoutSubtreeIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }
}
