import Combine
import Foundation
import ImageIO
import NengaCore
import SwiftUI
import UniformTypeIdentifiers

/// 1 冊分の年賀状プロジェクト（.nenga パッケージ）を SwiftUI の書類として扱う。

final class NengaProjectDocument: ReferenceFileDocument, ObservableObject {
    typealias Snapshot = NengaDocument

    static var readableContentTypes: [UTType] { [.nengaDocument] }

    // 編集はすべてメインアクター（SwiftUI のビュー）から行う。
    // ReferenceFileDocument は Sendable を要求するため、可変のプロパティについて
    // コンパイラが警告を出すが、実際のアクセスはメインスレッドに限られている。
    @Published var model: NengaDocument
    /// パッケージ内 assets の実データ（読み込んだ内容を保持して書き戻す）
    @Published var assets: [String: Data]
    /// 最後に読み書きしたファイルの URL（CSV の既定フォルダに使う）
    @Published var lastKnownURL: URL?

    init(model: NengaDocument = NengaDocument(year: NengaProjectDocument.defaultYear)) {
        self.model = model
        self.assets = [:]
    }

    required init(configuration: ReadConfiguration) throws {
        let loaded = try NengaProjectDocument.load(from: configuration.file)
        self.model = loaded.document
        self.assets = loaded.assets
    }

    static var defaultYear: Int {
        // 年賀状は「翌年分」を年明け前に作るため、12 月までは翌年を使う
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: Date())
        return year + 1
    }

    func snapshot(contentType: UTType) throws -> NengaDocument {
        model
    }

    func fileWrapper(snapshot: NengaDocument, configuration: WriteConfiguration) throws -> FileWrapper {
        try NengaProjectDocument.makeFileWrapper(document: snapshot, assets: assets)
    }

    /// パッケージの読み込み（`init(configuration:)` と自己診断から使う）。
    static func load(from wrapper: FileWrapper) throws -> (document: NengaDocument, assets: [String: Data]) {
        var loadedAssets: [String: Data] = [:]
        var document: NengaDocument

        if wrapper.isDirectory {
            guard let jsonWrapper = wrapper.fileWrappers?[DocumentStore.documentFileName],
                  let data = jsonWrapper.regularFileContents else {
                throw DocumentStore.StoreError.missingDocument(URL(fileURLWithPath: DocumentStore.documentFileName))
            }
            document = try JSONDecoder().decode(NengaDocument.self, from: data)
            if let assetWrappers = wrapper.fileWrappers?[DocumentStore.assetsDirectoryName]?.fileWrappers {
                for (name, assetWrapper) in assetWrappers {
                    if let data = assetWrapper.regularFileContents {
                        loadedAssets[name] = data
                    }
                }
            }
        } else if let data = wrapper.regularFileContents {
            document = try JSONDecoder().decode(NengaDocument.self, from: data)
        } else {
            throw DocumentStore.StoreError.missingDocument(URL(fileURLWithPath: DocumentStore.documentFileName))
        }
        return (document, loadedAssets)
    }

    /// パッケージの書き出し。
    static func makeFileWrapper(document: NengaDocument, assets: [String: Data]) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)

        let jsonWrapper = FileWrapper(regularFileWithContents: data)
        jsonWrapper.preferredFilename = DocumentStore.documentFileName

        var children: [String: FileWrapper] = [DocumentStore.documentFileName: jsonWrapper]
        if !assets.isEmpty {
            let assetWrappers = assets.mapValues { FileWrapper(regularFileWithContents: $0) }
            let directory = FileWrapper(directoryWithFileWrappers: assetWrappers)
            children[DocumentStore.assetsDirectoryName] = directory
        }
        let package = FileWrapper(directoryWithFileWrappers: children)
        package.preferredFilename = "年賀状.nenga"
        return package
    }

    // MARK: - 編集

    /// モデルを書き換える。Undo 対応。
    @MainActor
    func update(
        undoManager: UndoManager?,
        actionName: String,
        _ mutation: (inout NengaDocument) -> Void
    ) {
        let previous = model
        var updated = model
        mutation(&updated)
        guard updated != previous else { return }
        model = updated
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            let restore = previous
            target.update(undoManager: undoManager, actionName: actionName) { model in
                model = restore
            }
        }
        undoManager.setActionName(actionName)
    }

    func addAsset(data: Data, fileName: String) -> String {
        let name = DocumentStore.uniqueAssetName(fileName)
        assets[name] = data
        if !model.assetFileNames.contains(name) {
            model.assetFileNames.append(name)
        }
        return name
    }

    /// ドラッグ操作のあとで Undo に登録する（操作中の見た目は即時反映）。
    @MainActor
    func registerFrameUndo(elementID: UUID, frame: ElementFrame, actionName: String, undoManager: UndoManager?) {
        guard let undoManager else { return }
        let current = model.design[elementID]?.frame
        undoManager.registerUndo(withTarget: self) { target in
            target.model.design[elementID]?.frame = frame
            if let current {
                target.registerFrameUndo(
                    elementID: elementID,
                    frame: current,
                    actionName: actionName,
                    undoManager: undoManager
                )
            }
        }
        undoManager.setActionName(actionName)
    }

    func imageLoader() -> (String) -> CGImage? {
        { [weak self] name in
            guard let data = self?.assets[name] else { return nil }
            return Self.decodeImage(data)
        }
    }

    static func decodeImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
