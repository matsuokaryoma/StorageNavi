import Foundation
import UIKit

// ユーザー設定を管理するサービス（D-021）
// フェーズ1: 初回入力したユーザー名 + 端末の identifierForVendor で作業者を識別する
@MainActor
final class UserSettingsService: ObservableObject {

    // ユーザー名（UserDefaults に保存）
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: Keys.userName) }
    }

    // 端末 ID（identifierForVendor を初回取得時にキャッシュ）
    let deviceId: String

    // 自動アーカイブの最終チェック日（1日1回だけ確認する）
    @Published var lastArchiveCheckDate: Date? {
        didSet { UserDefaults.standard.set(lastArchiveCheckDate, forKey: Keys.lastArchiveCheckDate) }
    }

    // 初回セットアップが完了しているか
    var isSetupComplete: Bool {
        !userName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        // 保存済みのユーザー名を読み込む（なければ空文字）
        let savedName = UserDefaults.standard.string(forKey: Keys.userName) ?? ""
        self.userName = savedName

        // 端末 ID をキャッシュから読む。なければ identifierForVendor を取得してキャッシュ
        if let cached = UserDefaults.standard.string(forKey: Keys.deviceId) {
            self.deviceId = cached
        } else {
            let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            UserDefaults.standard.set(id, forKey: Keys.deviceId)
            self.deviceId = id
        }

        self.lastArchiveCheckDate = UserDefaults.standard.object(forKey: Keys.lastArchiveCheckDate) as? Date
    }

    private enum Keys {
        static let userName               = "userName"
        static let deviceId               = "deviceId"
        static let lastArchiveCheckDate   = "lastArchiveCheckDate"
    }
}
