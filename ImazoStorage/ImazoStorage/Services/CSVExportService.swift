import Foundation

// パーツデータを CSV ファイルとして書き出すサービス
// Excel で開いたときに文字化けしないよう UTF-8 BOM 付きで出力する
final class CSVExportService {

    static let shared = CSVExportService()
    private init() {}

    // MARK: - CSV 生成

    /// [Part] を CSV ファイルに変換し、一時ディレクトリの URL を返す
    func export(parts: [Part]) throws -> URL {
        var rows: [String] = []

        // ヘッダー行
        rows.append(csvRow([
            "ID", "パーツ名", "ステータス",
            "緯度", "経度", "GPS精度(m)",
            "備考", "OCRテキスト",
            "登録日時", "登録者",
            "更新日時", "更新者",
            "使用日時", "削除済み"
        ]))

        // データ行
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        formatter.timeZone = TimeZone.current

        for part in parts {
            rows.append(csvRow([
                part.id.uuidString,
                part.name,
                part.status.displayName,
                String(part.latitude),
                String(part.longitude),
                part.locationAccuracy.map { String($0) } ?? "",
                part.notes ?? "",
                part.ocrRawText ?? "",
                formatter.string(from: part.createdAt),
                part.createdBy,
                formatter.string(from: part.updatedAt),
                part.updatedBy,
                part.usedAt.map { formatter.string(from: $0) } ?? "",
                part.isDeleted ? "○" : ""
            ]))
        }

        // UTF-8 BOM + 改行は CRLF（Excel 互換）
        let bom  = "\u{FEFF}"
        let body = rows.joined(separator: "\r\n")
        let csv  = bom + body

        guard let data = csv.data(using: .utf8) else {
            throw ExportError.encodingFailed
        }

        // ファイル名: IMAZOデータ_20260426_1430.csv
        let stamp    = fileNameDateFormatter.string(from: Date())
        let fileName = "IMAZOデータ_\(stamp).csv"
        let url      = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - ヘルパー

    /// フィールドを RFC 4180 に従ってエスケープし、カンマ区切りの1行にする
    private func csvRow(_ fields: [String]) -> String {
        fields.map { field -> String in
            // カンマ・改行・ダブルクォートを含む場合はダブルクォートで囲む
            let needsQuoting = field.contains(",") || field.contains("\"")
                            || field.contains("\n") || field.contains("\r")
            if needsQuoting {
                let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\""
            }
            return field
        }
        .joined(separator: ",")
    }

    private lazy var fileNameDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd_HHmm"
        return f
    }()

    // MARK: - エラー

    enum ExportError: LocalizedError {
        case encodingFailed

        var errorDescription: String? {
            "CSV の文字エンコードに失敗しました"
        }
    }
}
