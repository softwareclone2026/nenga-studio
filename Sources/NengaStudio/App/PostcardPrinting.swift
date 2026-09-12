import AppKit
import NengaCore
import PDFKit

/// 印刷の設定と実行。用紙サイズは実寸（100×148mm または 148×100mm）に合わせる。
enum PostcardPrinting {
    static func printInfo(for document: NengaDocument) -> NSPrintInfo {
        let size = PostcardExport.pageSizePoints(document)
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.paperSize = size
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.orientation = size.height > size.width ? .portrait : .landscape
        info.horizontalPagination = .clip
        info.verticalPagination = .clip
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.scalingFactor = 1.0
        return info
    }

    /// PDF を作って印刷パネルを出す。失敗したら理由を返す。
    @discardableResult
    static func print(
        document: NengaDocument,
        pages: [PostcardPage],
        jobName: String,
        assetLoader: ((String) -> CGImage?)? = nil
    ) -> String? {
        do {
            let data = try PostcardExport.makePDF(
                document: document,
                pages: pages,
                mode: .print,
                assetLoader: assetLoader
            )
            guard let pdf = PDFDocument(data: data) else {
                return "PDF を開けませんでした。"
            }
            let info = printInfo(for: document)
            guard let operation = pdf.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: false) else {
                return "印刷を開始できませんでした。"
            }
            operation.jobTitle = jobName
            operation.showsPrintPanel = true
            operation.showsProgressPanel = true
            operation.run()
            return nil
        } catch {
            return "印刷データを作成できませんでした: \(error.localizedDescription)"
        }
    }
}
