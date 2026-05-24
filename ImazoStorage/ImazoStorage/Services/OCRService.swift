import Vision
import UIKit

// OCR 認識結果（パーツ名候補 + 全行）
struct OCRFullResult {
    // バウンディングボックスが最も高い観測 = 最も大きい文字 → パーツ名の候補
    let primaryText: String
    // 全認識行（ocrRawText に格納する生テキスト）
    let allLines: [String]
}

// Vision フレームワークを使って画像からテキストを抽出するサービス（D-001, D-028）
final class OCRService {

    // primaryText（最大文字）と全行を同時に返す
    func recognizeFull(image: UIImage) async throws -> OCRFullResult {
        guard let cgImage = image.cgImage else {
            return OCRFullResult(primaryText: "", allLines: [])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }

                // バウンディングボックスの高さが最大 = 最も大きく印字された文字
                let primary = observations
                    .max(by: { $0.boundingBox.height < $1.boundingBox.height })?
                    .topCandidates(1).first?.string ?? lines.first ?? ""

                continuation.resume(returning: OCRFullResult(primaryText: primary, allLines: lines))
            }

            // D-028: 日本語 + 英数字の複数言語を指定
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // 複数行の認識結果を1つの文字列にまとめるユーティリティ
    func join(lines: [String]) -> String {
        lines.joined(separator: "\n")
    }
}
