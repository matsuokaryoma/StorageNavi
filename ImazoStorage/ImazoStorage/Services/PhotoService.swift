import UIKit
import Foundation

// パーツ写真の保存・読み込みを管理するサービス
// D-022: JPEG品質80%、長辺1600pxにリサイズ
// D-023: 登録時のOCR元画像を1枚目として自動保存
// D-032: 保存先ディレクトリに .noBackup を付与
final class PhotoService {

    static let shared = PhotoService()

    // 写真の保存先ディレクトリ（Application Support/PartPhotos/）
    private let photosDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PartPhotos", isDirectory: true)

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // D-032: ディレクトリを iCloud バックアップ対象外にする
        var mutableURL = dir
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(rv)

        return dir
    }()

    // UIImage を圧縮・保存してファイル名を返す
    // Part.photo1Path / photo2Path にはこのファイル名を保存する
    func save(image: UIImage) throws -> String {
        let resized = resize(image: image, maxLongSide: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.8) else {
            throw PhotoError.compressionFailed
        }

        let fileName = UUID().uuidString + ".jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try data.write(to: fileURL)

        // D-031/D-032: バックアップ除外 + データ保護レベルを設定
        var mutableURL = fileURL
        var rv = URLResourceValues()
        rv.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(rv)
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )

        return fileName
    }

    // ファイル名から UIImage を読み込む
    func load(fileName: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    // ファイルを削除する（論理削除時など）
    func delete(fileName: String) {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - 長辺リサイズ
    private func resize(image: UIImage, maxLongSide: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxLongSide else { return image }

        let scale = maxLongSide / longSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

enum PhotoError: LocalizedError {
    case compressionFailed
    var errorDescription: String? { "画像の圧縮に失敗しました" }
}
