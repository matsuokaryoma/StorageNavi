import Foundation
import SwiftData

// パーツに対して何が起きたかを表すイベント種別
enum PartEventType: String, Codable {
    case registered         = "registered"          // 新規登録
    case edited             = "edited"              // 項目編集
    case markedAsUsed       = "markedAsUsed"        // 使用済みへ変更
    case returnedToStorage  = "returnedToStorage"   // 置場に戻した
    case locationUpdated    = "locationUpdated"     // 位置情報更新
    case photoAdded         = "photoAdded"          // 写真追加
    case photoReplaced      = "photoReplaced"       // 写真差し替え
    case photoRemoved       = "photoRemoved"        // 写真削除
    case softDeleted        = "softDeleted"         // 論理削除

    var displayName: String {
        switch self {
        case .registered:        return "登録"
        case .edited:            return "編集"
        case .markedAsUsed:      return "使用済みに変更"
        case .returnedToStorage: return "置場に戻した"
        case .locationUpdated:   return "位置情報更新"
        case .photoAdded:        return "写真追加"
        case .photoReplaced:     return "写真差し替え"
        case .photoRemoved:      return "写真削除"
        case .softDeleted:       return "削除"
        }
    }
}

// パーツへの変更を記録する監査ログエンティティ
// append-only: INSERT のみ。UPDATE / DELETE は絶対に行わない
@Model
final class PartEvent {
    // MARK: - 識別情報
    var id: UUID
    var partId: UUID        // 対象パーツの Part.id
    var partNameSnapshot: String  // 記録時点でのパーツ名（Part削除後も監査できるように保持）

    // MARK: - イベント種別
    // RawRepresentable な enum は SwiftData で直接保持できないため String で保存する
    var eventTypeRaw: String
    var eventType: PartEventType {
        get { PartEventType(rawValue: eventTypeRaw) ?? .edited }
        set { eventTypeRaw = newValue.rawValue }
    }

    // MARK: - 変更内容
    // edited / locationUpdated / 写真系イベントで変更フィールドの before/after を JSON 文字列として保持
    // 例: [{"field":"name","before":"A-001","after":"A-002"}]
    var changesJSON: String?

    // MARK: - 操作者・端末
    var actorId: String    // 実行者ID（フェーズ1: identifierForVendor）
    var actorName: String  // 実行者名（その時点での表示名）
    var deviceId: String   // 端末識別子

    // MARK: - 発生日時
    var occurredAt: Date  // イベント発生日時（システム時刻のみ使用）

    // MARK: - イベント発生時の端末位置（監査用）
    var eventLatitude: Double?
    var eventLongitude: Double?
    var eventLocationAccuracy: Double?

    // MARK: - 初期化
    init(
        id: UUID = UUID(),
        partId: UUID,
        partNameSnapshot: String,
        eventType: PartEventType,
        changesJSON: String? = nil,
        actorId: String,
        actorName: String,
        deviceId: String,
        occurredAt: Date = Date(),
        eventLatitude: Double? = nil,
        eventLongitude: Double? = nil,
        eventLocationAccuracy: Double? = nil
    ) {
        self.id = id
        self.partId = partId
        self.partNameSnapshot = partNameSnapshot
        self.eventTypeRaw = eventType.rawValue
        self.changesJSON = changesJSON
        self.actorId = actorId
        self.actorName = actorName
        self.deviceId = deviceId
        self.occurredAt = occurredAt
        self.eventLatitude = eventLatitude
        self.eventLongitude = eventLongitude
        self.eventLocationAccuracy = eventLocationAccuracy
    }
}
