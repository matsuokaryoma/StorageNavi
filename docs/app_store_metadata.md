# App Store Connect 登録情報

TestFlight / App Store 申請時に App Store Connect へ貼り付ける文言集。

---

## 基本情報

| 項目 | 内容 | 文字数制限 |
|---|---|---|
| **アプリ名** | 置場ナビ | 30文字以内 |
| **サブタイトル** | アイテムの置場をスキャンして記録・検索 | 30文字以内 |
| **カテゴリ** | ビジネス（第1）/ ユーティリティ（第2） | — |
| **価格** | 無料 | — |
| **年齢レーティング** | 4+ | — |
| **対応言語** | 日本語 | — |

---

## 説明文（App Store 掲載用）

```
置場ナビは、現場作業者がアイテムの置き場所をカメラでスキャンして記録・検索できるiOSアプリです。

【主な機能】

📷 カメラでスキャン→即登録
カメラをアイテムにかざすだけで印字文字を自動読み取り（OCR）。GPS位置情報も同時取得し、置き場所をワンタップで記録できます。

🔍 すばやく見つかる
パーツ名の一部で検索するだけでヒット。カメラでスキャンした結果をそのまま検索クエリにも使えます。

🗺️ 地図で場所を確認
登録した置き場所を地図上で表示。全アイテムをまとめて地図に表示する機能も備えています。

✅ ステータス管理
「保管中」「使用済み」のステータスで管理。使用したアイテムはその場でステータス更新できます。

📋 監査ログ
誰が・いつ・何を操作したか、すべての変更履歴を自動記録。後から確認できます。

📤 CSVエクスポート
全データをCSVファイルに書き出してメール・AirDropで共有できます。

【こんな現場に】
・広い置場でアイテムがどこにあるか分からなくなる
・アイテムを使ったかどうか、口頭で確認しなければならない
・担当者が変わると情報が引き継げない

【プライバシーについて】
すべてのデータはお使いのiPhone内にのみ保存されます。
外部サーバーへの送信は一切ありません。
```

---

## キーワード（100文字以内・カンマ区切り）

```
置場,在庫管理,OCR,スキャン,パーツ管理,位置情報,GPS,現場,工場,倉庫,QR,バーコード,資材
```

---

## サポートURL・プライバシーポリシーURL

| 項目 | URL |
|---|---|
| **サポートURL** | `https://matsuokaryoma.github.io/StorageNavi/` |
| **プライバシーポリシーURL** | `https://matsuokaryoma.github.io/StorageNavi/privacy_policy` |

---

## プライバシーの質問への回答（App Store Connect）

App Store Connect の「App Privacy」セクションで以下のように回答してください。

### データ収集の有無
**「はい、データを収集します」** を選択

### 収集するデータの種類

| データの種類 | 収集 | 理由 |
|---|---|---|
| 位置情報（正確な位置） | ✅ はい | アイテムの置き場所を記録するため |
| カメラ（写真・ビデオ） | ✅ はい | アイテムの写真を記録するため |
| ユーザーコンテンツ（ユーザー生成コンテンツ） | ✅ はい | アイテム名・備考の入力 |
| 識別子（デバイスID） | ✅ はい | 操作者を識別するため |
| 連絡先情報（氏名） | ✅ はい | 操作者名として保存 |

### データのトラッキング
**「いいえ」** — ユーザーを追跡するための目的では使用しません

### データがデバイス外に送信されるか
**「いいえ」** — すべてのデータは端末内にのみ保存されます

---

## App Store 審査メモ（Review Notes）

審査担当者向けのメモ（英語推奨）：

```
This app is designed for industrial/warehouse workers to record and locate stored items using camera OCR and GPS.

Test account is not required — all features are accessible without login.
On first launch, the app requests a user name (any name is accepted, e.g., "TestUser").

Camera permission: Used to scan printed text on items via OCR.
Location permission: Used to record the GPS coordinates of item storage locations.

All data is stored locally on the device. No network connection is required.
```

---

## スクリーンショット撮影チェックリスト

App Store には各デバイスサイズのスクリーンショットが必要です。
Xcodeシミュレータで撮影してください（⌘+S でスクリーンショット）。

### 必要なサイズ（最低限）
- **iPhone 6.9インチ**（iPhone 16 Pro Max シミュレータ）← 必須
- **iPhone 6.5インチ**（iPhone 15 Plus シミュレータ）← 必須

### 撮るべき画面（各3〜5枚）
1. ホーム画面（登録する・データを探す・地図で見る のボタンが見える状態）
2. カメラ/OCR 画面
3. 検索結果一覧
4. パーツ詳細画面（情報タブ）
5. 全パーツ地図画面
