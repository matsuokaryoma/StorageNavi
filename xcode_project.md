# Xcodeプロジェクト構成

最終更新: 2026-04-24

## 基本情報

| 項目 | 値 |
|---|---|
| Xcodeプロジェクト名 | `ImazoStorage` |
| アプリ表示名 | `IMAZO置場管理` |
| Bundle ID | `dev.matsuokaryoma.ImazoStorage` |
| 最低対応iOS | iOS 17.0 |
| 言語 | Swift |
| UI | SwiftUI |
| データ保存 | SwiftData |
| 画面向き | 縦向き固定 |
| UI言語 | 日本語のみ |

## ディレクトリ構成

```
~/Documents/ShipyardPartsApp/       ← Gitルート
├── docs（仕様書群）
│   requirements.md / decisions.md / screens.md /
│   data_model.md / non_functional.md / xcode_project.md
├── .gitignore
└── ImazoStorage/                    ← Xcodeプロジェクト
    ├── ImazoStorage.xcodeproj
    └── ImazoStorage/
        ├── App/            アプリエントリポイント
        ├── Models/         SwiftDataのエンティティ（Part, PartEvent）
        ├── Views/          SwiftUI画面
        ├── ViewModels/     画面ロジック
        ├── Services/       OCR・位置情報・写真・Repository・監査ログ
        ├── Components/     再利用UI部品
        ├── Resources/      画像・色定義
        └── Info.plist
```

## 使用フレームワーク

| 用途 | フレームワーク |
|---|---|
| UI | SwiftUI |
| データ永続化 | SwiftData |
| カメラ | AVFoundation |
| OCR | Vision（VNRecognizeTextRequest）|
| 位置情報 | CoreLocation |
| 地図 | MapKit |
| フェーズ2のOneDrive連携 | MSAL + Microsoft Graph（後日追加）|

外部依存はフェーズ1では追加なし。全てApple標準。

## Info.plist に必要な権限文言

| キー | 文言（案）|
|---|---|
| `NSCameraUsageDescription` | パーツの文字情報をカメラで読み取るために使用します |
| `NSLocationWhenInUseUsageDescription` | パーツの所在地を記録するために現在地を使用します |
| `NSPhotoLibraryAddUsageDescription` | 登録時の写真を保存するために使用します（必要なら）|

## Apple Developer アカウント

- **フェーズ1**: 個人Apple IDで開発。実機インストールはFree Provisioning（7日間ごとに再ビルド必要）
- 本格運用に進む段階で有料の Apple Developer Program 登録を検討
- 会社展開時は**新Bundle IDで会社アカウントに新規登録**する想定

## Git管理

- `~/Documents/ShipyardPartsApp/` を Git リポジトリとして初期化
- 仕様書とXcodeプロジェクトを同一リポジトリで管理
- リモートリポジトリ（GitHub等）への push は任意、当面ローカルのみ
