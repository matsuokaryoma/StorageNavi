# Xcodeプロジェクト 作成手順

## 0. 前提

- macOSにXcode 15以上がインストール済み
- 個人のApple IDがXcodeにサインイン済み（Xcode → Settings → Accounts）

## 1. プロジェクト新規作成

1. Xcode を起動 → **Create New Project**
2. **iOS** タブ → **App** を選択 → Next
3. 以下を入力：

| 項目 | 値 |
|---|---|
| Product Name | `ImazoStorage` |
| Team | あなたの個人Apple ID（Personal Team）|
| Organization Identifier | `dev.matsuokaryoma` |
| Bundle Identifier | （自動で `dev.matsuokaryoma.imazostorage` になる）|
| Interface | **SwiftUI** |
| Language | **Swift** |
| Storage | **SwiftData** |
| Include Tests | お好みで（ON推奨）|

4. Next を押し、保存先を **`~/Documents/ShipyardPartsApp/`** に指定
5. **「Create Git repository on my Mac」のチェックは外す** ← 親フォルダで既にGit管理しているため

## 2. プロジェクト設定

プロジェクトナビゲータで `ImazoStorage` をクリック → ターゲット `ImazoStorage` を選択。

### General タブ
- **Minimum Deployments**: `iOS 17.0`
- **Display Name**: `IMAZO置場管理`
- **Supported Destinations**: iPhone のみ
- **Device Orientation**: Portrait のみON、他はOFF

### Info タブ（権限の文言）
以下のキーを追加：

| Key | Type | Value |
|---|---|---|
| `Privacy - Camera Usage Description` | String | パーツの文字情報をカメラで読み取るために使用します |
| `Privacy - Location When In Use Usage Description` | String | パーツの所在地を記録するために現在地を使用します |

## 3. ディレクトリ作成

プロジェクトナビゲータで `ImazoStorage` フォルダを右クリック → **New Group** で以下を作成：

- App（既存の `ImazoStorageApp.swift` をここへ移動）
- Models
- Views（既存の `ContentView.swift` をここへ移動）
- ViewModels
- Services
- Components
- Resources

## 4. ビルド確認

`⌘+R` でシミュレータ起動。デフォルトの "Hello, world!" が出ればOK。

## 5. Gitコミット

ターミナルで：

```bash
cd ~/Documents/ShipyardPartsApp/
git status        # 新規作成されたXcodeプロジェクトが見える
git add .
git commit -m "Add Xcode project skeleton"
```

## つまずきポイント

- **Bundle ID重複エラー**: Apple IDで既に同じBundle IDを使っている人がいる場合、後ろに数字を付ける（例: `dev.matsuokaryoma.imazostorage1`）
- **無料プロビジョニングの7日制限**: 個人Apple IDで実機にインストールすると7日で再ビルド必要。シミュレータなら制限なし。
- **Personal Teamが見えない**: Xcode → Settings → Accounts で Apple ID を再ログイン
