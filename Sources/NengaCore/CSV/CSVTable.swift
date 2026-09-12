import Foundation

/// 引用符・改行・カンマを扱える最小限の CSV パーサ。
public struct CSVTable: Sendable {
    public var rows: [[String]]

    public init(rows: [[String]]) {
        self.rows = rows
    }

    public init(text: String) {
        self.rows = CSVTable.parse(text)
    }

    public static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text)
        var index = 0

        func finishField() {
            row.append(field)
            field = ""
        }

        func finishRow() {
            finishField()
            // 空行は無視する
            if !(row.count == 1 && row[0].trimmingCharacters(in: .whitespaces).isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while index < iterator.count {
            let character = iterator[index]
            if inQuotes {
                if character == "\"" {
                    if index + 1 < iterator.count, iterator[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    finishField()
                // Swift では CRLF が 1 文字として扱われるため両方を受け付ける
                case "\n", "\r\n", "\r":
                    finishRow()
                default:
                    field.append(character)
                }
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            finishRow()
        }
        return rows
    }

    public func text(separator: String = ",") -> String {
        rows.map { row in
            row.map { CSVTable.escape($0) }.joined(separator: separator)
        }.joined(separator: "\r\n") + "\r\n"
    }

    public static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
