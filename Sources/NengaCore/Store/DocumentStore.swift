import Foundation

/// `.nenga` パッケージ（フォルダ）の読み書き。
/// 中身は document.json と assets/ ディレクトリ。
public enum DocumentStore {
    public static let documentFileName = "document.json"
    public static let assetsDirectoryName = "assets"
    public static let fileExtension = "nenga"

    public enum StoreError: Error, LocalizedError {
        case missingDocument(URL)
        case unsupportedVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .missingDocument(let url):
                "\(url.lastPathComponent) に \(documentFileName) が見つかりません。"
            case .unsupportedVersion(let version):
                "このファイルは新しい形式（version \(version)）で保存されています。"
            }
        }
    }

    public static func write(_ document: NengaDocument, to url: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: url.appendingPathComponent(assetsDirectoryName),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        try data.write(to: url.appendingPathComponent(documentFileName), options: .atomic)
    }

    public static func read(from url: URL) throws -> NengaDocument {
        let documentURL = url.appendingPathComponent(documentFileName)
        guard FileManager.default.fileExists(atPath: documentURL.path) else {
            // 拡張子なしのフォルダや、単一 JSON ファイルも受け付ける
            if url.pathExtension == "json", let data = try? Data(contentsOf: url) {
                return try JSONDecoder().decode(NengaDocument.self, from: data)
            }
            throw StoreError.missingDocument(url)
        }
        let data = try Data(contentsOf: documentURL)
        let document = try JSONDecoder().decode(NengaDocument.self, from: data)
        guard document.formatVersion <= NengaDocument.currentFormatVersion else {
            throw StoreError.unsupportedVersion(document.formatVersion)
        }
        return document
    }

    /// 画像などのリソースをパッケージへ追加する。
    @discardableResult
    public static func addAsset(data: Data, fileName: String, to url: URL) throws -> String {
        let directory = url.appendingPathComponent(assetsDirectoryName)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = uniqueAssetName(fileName)
        try data.write(to: directory.appendingPathComponent(safeName), options: .atomic)
        return safeName
    }

    public static func assetURL(fileName: String, in url: URL) -> URL {
        url.appendingPathComponent(assetsDirectoryName).appendingPathComponent(fileName)
    }

    public static func uniqueAssetName(_ fileName: String) -> String {
        let sanitized = fileName.replacingOccurrences(of: "/", with: "_")
        return "\(UUID().uuidString.prefix(8))-\(sanitized)"
    }
}
