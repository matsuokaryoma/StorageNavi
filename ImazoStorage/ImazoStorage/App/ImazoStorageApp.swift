//
//  ImazoStorageApp.swift
//  ImazoStorage
//
//  Created by リョーマ on 2026/04/25.
//

import SwiftUI
import SwiftData

@main
struct ImazoStorageApp: App {
    // SwiftData の永続化コンテナ。Part と PartEvent の2エンティティを登録する
    // D-032: ストアファイルの保存先を明示指定し、iCloud バックアップ対象外にする
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Part.self, PartEvent.self])

        // Application Support 直下にストアファイルを置く
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let storeURL   = appSupport.appendingPathComponent("ImazoStorage.store")
        let config     = ModelConfiguration(schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(for: schema, configurations: [config])

            // D-031/D-032: バックアップ除外 + データ保護レベルを設定
            var url = storeURL
            var rv  = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? url.setResourceValues(rv)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: storeURL.path
            )

            return container
        } catch {
            fatalError("ModelContainer の作成に失敗しました: \(error)")
        }
    }()

    // アプリ全体で共有するユーザー設定
    @StateObject private var userSettings = UserSettingsService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userSettings)
                // セットアップ未完了（初回起動）なら名前入力画面をフルスクリーンで表示
                .fullScreenCover(isPresented: Binding(
                    get: { !userSettings.isSetupComplete },
                    set: { _ in }
                )) {
                    NavigationStack {
                        UserSetupView()
                            .environmentObject(userSettings)
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
