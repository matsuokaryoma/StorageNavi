import Foundation
import SwiftData

// パーツのステータス（保管中 / 使用済み）
enum PartStatus: String, Codable {
    case inStorage = "inStorage"  // 保管中
    case used = "used"            // 使用済み

    var displayName: String {
        switch self {
        case .inStorage: return "保管中"
        case .used: return "使用済み"
        }
    }
}

// パーツの現在状態を表すエンティティ
// 「今どうなっているか」を保持する。変更履歴は PartEvent で管理する
@Model
final class Part {
    // MARK: - 識別情報
    var id: UUID
    // パーツ名（OCR結果 or ユーザー修正後の文字列）。ユーザーが目にする唯一のキー
    var name: String

    // MARK: - ステータス
    // RawRepresentable な enum は SwiftData で直接保持できないため String で保存し、
    // 計算プロパティ経由で PartStatus として読み書きする
    var statusRaw: String
    var status: PartStatus {
        get { PartStatus(rawValue: statusRaw) ?? .inStorage }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: - 位置情報
    var latitude: Double
    var longitude: Double
    var locationAccuracy: Double?  // GPS精度（メートル）。取得できない場合は nil

    // MARK: - 補足情報
    var notes: String?       // 備考（自由記述、最大500文字）
    var ocrRawText: String?  // OCRの生結果。ユーザー修正前の文字列を誤認識分析用に保持

    // MARK: - 写真（最大2枚）
    var photo1Path: String?  // 登録時のOCR元画像のローカルパス
    var photo2Path: String?  // 任意で追加した2枚目のローカルパス

    // MARK: - 論理削除
    var isDeleted: Bool  // true にすると一覧から非表示になる（物理削除はしない）

    // MARK: - 日時・操作者
    var createdAt: Date    // 登録日時（一度セットしたら変更しない）
    var createdBy: String  // 登録者ID（フェーズ1: 端末のidentifierForVendor）
    var updatedAt: Date    // 最終更新日時
    var updatedBy: String  // 最終更新者ID
    var usedAt: Date?      // 使用日時（status == .used のときのみセット）

    // MARK: - 初期化
    init(
        id: UUID = UUID(),
        name: String,
        status: PartStatus = .inStorage,
        latitude: Double,
        longitude: Double,
        locationAccuracy: Double? = nil,
        notes: String? = nil,
        ocrRawText: String? = nil,
        photo1Path: String? = nil,
        photo2Path: String? = nil,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        createdBy: String,
        updatedAt: Date = Date(),
        updatedBy: String,
        usedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.statusRaw = status.rawValue
        self.latitude = latitude
        self.longitude = longitude
        self.locationAccuracy = locationAccuracy
        self.notes = notes
        self.ocrRawText = ocrRawText
        self.photo1Path = photo1Path
        self.photo2Path = photo2Path
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.updatedAt = updatedAt
        self.updatedBy = updatedBy
        self.usedAt = usedAt
    }
}
