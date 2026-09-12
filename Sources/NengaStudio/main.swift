import Foundation
import NengaCore

// エントリポイント。--render-* 系の引数があるときはヘッドレスで描画し、
// それ以外は SwiftUI アプリとして起動する（アプリ本体は App/ 以下）。
let arguments = CommandLine.arguments

func argumentValue(_ name: String) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

if arguments.contains("--help") || arguments.contains("-h") {
    print("""
    NengaStudio — 年賀スタジオ（macOS 版 年賀状ソフト）

      引数なし                  アプリとして起動
      --render-samples <dir>    サンプルのはがき PDF / PNG を出力
      --render-ui <dir>         画面のスクリーンショットを出力
      --make-sample <path>      サンプルの .nenga ファイルを作成
      --inspect <path>          .nenga の中身を表示
      --make-icon <path>        アプリアイコンを PNG で出力
      --version                 バージョンを表示
    """)
    exit(0)
}

if arguments.contains("--version") {
    print("NengaStudio 1.0")
    exit(0)
}

if let directory = argumentValue("--render-samples") {
    exit(RenderSamples.run(outputDirectory: directory))
}

if let path = argumentValue("--make-sample") {
    exit(RenderSamples.writeSampleDocument(to: path))
}

if let path = argumentValue("--inspect") {
    exit(RenderSamples.inspect(path: path))
}

if let directory = argumentValue("--render-ui") {
    exit(RenderScreenshots.run(outputDirectory: directory))
}

if arguments.contains("--self-check") {
    exit(SelfCheck.run())
}

if let path = argumentValue("--make-icon") {
    exit(MakeIcon.run(outputPath: path))
}

NengaStudioApp.main()
