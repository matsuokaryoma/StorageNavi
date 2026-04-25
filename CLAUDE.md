# IMAZO置場管理 — Claude Code 用ガイド

造船所の鉄板加工〜組立工程間のパーツ置場を管理する iOS アプリのリポジトリ。
このファイルは Claude Code が起動時に自動で読み込む前提のガイド。

## まず読むドキュメント

実装着手前に必ず以下に目を通すこと。判断に迷ったら必ずここに戻る。

| ファイル | 内容 |
|---|---|
| `requirements.md` | 要件定義 |
| `screens.md` | 画面構成・ユーザーフロー |
| `data_model.md` | エンティティ定義（Part / PartEvent） |
| `non_functional.md` | 非機能仕様 |
| `xcode_project.md` | Xcodeプロジェクト構成 |
| `decisions.md` | 決定事項ログ（D-001〜）— **最重要** |

`decisions.md` には合意済みの判断が時系列で並ぶ。実装方針で迷ったら最優先で参照。

## プロジェクト基本情報

- **アプリ表示名**: IMAZO置場管理
- **Xcodeプロジェクト名**: ImazoStorage
- **Bundle ID**: `dev.matsuokaryoma.ImazoStorage`
- **最低対応iOS**: 17.0（SwiftData利用のため）
- **基準端末**: iPhone SE 第3世代（4.7"）
- **言語/UI**: Swift / SwiftUI
- **永続化**: SwiftData（フェーズ1はローカルのみ）
- **UI言語**: 日本語のみ

## 鉄則（絶対守ること）

1. **監査ログ append-only**: `PartEvent` は一度書いたら更新・削除しない。`Part` への変更が起きたら必ず対応する `PartEvent` を追加する。
2. **破壊的アクションは確認ダイアログ**: 使用済みにする / 位置情報を更新する / 置場に戻す / 論理削除 は全て確認を挟む。
3. **物理削除しない**: 削除は `isDeleted` フラグでの論理削除のみ。`PartEvent` は保持。
4. **デフォルトは「保管中」のみ表示**: 使用済みはフィルタ切替時のみ表示。
5. **詳細画面のボタンはステータスで出し分け**: 保管中＝編集/使用済みにする/位置情報を更新する、使用済み＝置場に戻す のみ。
6. **iCloudバックアップ対象外**: ローカルDBと写真ファイルに `.noBackup` 属性を付与。
7. **タップ領域は最低48pt**: 手袋・屋外を想定。

## ディレクトリ構成（Xcodeプロジェクト内）

```
ImazoStorage/
├── App/            アプリエントリポイント
├── Models/         SwiftData エンティティ（Part, PartEvent）
├── Views/          SwiftUI画面（HomeView, CameraOCRView, PartDetailView, SearchView, SearchResultsView）
├── ViewModels/     画面ロジック
├── Services/       OCRService / LocationService / PhotoService / PartRepository / AuditLogger
├── Components/     再利用UI
└── Resources/      画像・色定義
```

## 命名規約

- 型名: UpperCamelCase（例: `PartDetailView`）
- 変数・関数: lowerCamelCase（例: `markAsUsed`）
- ファイル名: 主たる型名と一致
- コメント: 日本語OK。コード自体（型名・変数名）は英語

## 動作確認

- ビルド/実行: Xcodeから `⌘+R` でシミュレータ起動
- 実機: 個人Apple ID + Free Provisioning（7日ごとに再ビルド必要）

## ユーザーについて

オーナー（Ryoma）は **Apple アプリ開発が初めて**。Swift/SwiftUI/SwiftData も初学者の前提。

- 生成コードには日本語コメントを多めに
- 一度に大量のコードを出すより、**ファイル単位・段階的**に進める
- 各実装ステップで「これは何をしているか」「次にどうしたいか」を簡潔に説明する
- ハマったときは原因を一緒に探る姿勢で

## 仕様変更時のルール

- 仕様変更があったら、まず `decisions.md` に新しいDナンバーで追記
- 影響範囲（requirements.md, screens.md など）を該当ファイルにも反映
- 必要に応じてこの `CLAUDE.md` も更新
