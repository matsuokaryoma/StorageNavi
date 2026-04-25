# データモデル設計

最終更新: 2026-04-24

## 全体方針

- **Part** エンティティ … パーツの現在状態（1パーツ=1行、更新で上書き）
- **PartEvent** エンティティ … 変更履歴。**追記専用（append-only）** で一切更新・削除しない。監査証跡として使う
- **Photo** エンティティ … 写真のメタ情報。実ファイルは端末のローカルストレージに保存し、パスを参照

Partで「今どうなっているか」を見せ、PartEventで「これまで何があったか」を追えるようにする。使用済みにする・置場に戻す・位置を更新する等の**全ての変化は必ずPartEventに1行記録**する。

---

## 1. Part エンティティ（現在状態）

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | UUID | ○ | 内部ID。PartEventからの参照キー。ユーザーには非表示 |
| `name` | String | ○ | パーツ名（OCR結果 or 修正後の文字列）。**ユーザー可視の一意キー** |
| `status` | Enum | ○ | `inStorage` / `used` |
| `latitude` | Double | ○ | 緯度 |
| `longitude` | Double | ○ | 経度 |
| `locationAccuracy` | Double? | − | GPS精度（メートル） |
| `notes` | String? | − | 備考欄（自由記述） |
| `ocrRawText` | String? | − | OCRの生結果（ユーザー修正前の文字列）。誤認識分析用 |
| `photo1Path` | String? | − | 写真1のローカルパス（登録時のOCR元画像） |
| `photo2Path` | String? | − | 写真2のローカルパス（任意の追加写真） |
| `isDeleted` | Bool | ○ | 論理削除フラグ（D-024）。trueの行は一覧非表示 |
| `createdAt` | Date | ○ | 登録日時 |
| `createdBy` | String | ○ | 登録者ID |
| `updatedAt` | Date | ○ | 最終更新日時 |
| `updatedBy` | String | ○ | 最終更新者ID |
| `usedAt` | Date? | − | 使用日時（使用済み化時にセット、置場に戻すと null） |

### 不変条件

- `name` はユーザー入力上一意。重複登録時は上書きor別名保存をユーザーに選ばせる（D-002）
- `status == .used` のときのみ `usedAt` がセットされる
- `createdAt` / `createdBy` は一度セットされたら変更されない

---

## 2. PartEvent エンティティ（監査ログ）

変更があるたびに1行追加される。**既存レコードは絶対に更新・削除しない。**

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `id` | UUID | ○ | イベントID |
| `partId` | UUID | ○ | 対象パーツ（Part.id への参照） |
| `partNameSnapshot` | String | ○ | その時点でのパーツ名（Part削除後の監査のため） |
| `eventType` | Enum | ○ | 下記参照 |
| `changes` | JSON | − | フィールド変更の詳細（`updated` 系イベントで使用） |
| `actorId` | String | ○ | 実行者ID |
| `actorName` | String | ○ | 実行者名（その時点） |
| `deviceId` | String | ○ | 端末識別子 |
| `occurredAt` | Date | ○ | イベント発生日時 |
| `eventLatitude` | Double? | − | イベント発生時の端末位置（監査用） |
| `eventLongitude` | Double? | − | 同上 |
| `eventLocationAccuracy` | Double? | − | 同上のGPS精度 |

### `eventType` の一覧

| 値 | 意味 | 使用される場面 |
|---|---|---|
| `registered` | 新規登録 | 登録フローの保存時 |
| `edited` | 項目編集 | 編集モードの保存時。`changes` に差分を入れる |
| `markedAsUsed` | 使用済みへ | 「使用済みにする」確定時 |
| `returnedToStorage` | 置場に戻した | 「置場に戻す」確定時 |
| `locationUpdated` | 位置情報更新 | 「位置情報を更新する」確定時。`changes` に before/after 緯度経度 |
| `photoAdded` | 写真追加 | 写真を追加したとき |
| `photoReplaced` | 写真差し替え | 既存写真を置き換えたとき |
| `photoRemoved` | 写真削除 | 写真を削除したとき |
| `softDeleted` | 論理削除 | パーツを削除したとき（isDeleted=true）|

### `changes` JSON の構造

`edited`, `locationUpdated`, 写真系イベントで使用。変更のあったフィールドだけ入る。

```json
[
  { "field": "name", "before": "A-1234", "after": "A-1235" },
  { "field": "notes", "before": null, "after": "歪みあり、要確認" }
]
```

### 不変条件

- **append-only**: INSERT のみ。UPDATE / DELETE 禁止（DB権限やアプリコードで保証）
- `occurredAt` は挿入時のシステム時刻のみ使用（手入力不可）
- Part が後に削除されても、PartEvent は残す（監査証跡保持のため）

---

## 3. Photo の扱い

- 1レコードにつき**最大2枚**（D-017）
- 実ファイルは端末ローカルストレージに保存
- ファイル名は UUID ベースで生成（衝突回避）
- Part.photo1Path / photo2Path に相対パスを保持
- 写真の**追加・差し替え・削除**も PartEvent に記録する（誰がいつ証拠写真を差し替えたか追えるようにする）

---

## 4. 登録者・更新者（Actor）の識別

### フェーズ1（ローカル動作版）

- **初回起動時**にユーザー名を入力してもらい、端末内に保存
- `actorId` は `identifierForVendor` 等の端末一意ID
- `actorName` は入力されたユーザー名
- 同じ端末を複数人で使い回す運用がなければこれで十分

### フェーズ2（OneDrive連携版）

- Microsoft アカウントでサインイン → そのアカウントのIDと表示名を使用
- フェーズ1のデータはマイグレーション時にActorを引き継ぐ

---

## 5. PartStatus 列挙型

| 値 | 表示名 |
|---|---|
| `inStorage` | 保管中 |
| `used` | 使用済み |

---

## 6. エンティティ関係図（概念）

```
[Part] 1 ────────── N [PartEvent]
   │
   │ 1
   │
   │ 0..2
   │
[Photo ファイル（外部保存）]
```

- 1つの Part に対して N個の PartEvent
- 1つの Part に対して 0〜2個の写真ファイル

---

## 7. フェーズ2（同期）に向けた留意点

今のうちに決めておかないと後で手戻りが出る項目：

- **ID は UUID** なので端末間で重複しない → 同期時の主キー衝突は起きない
- **Part は最終更新の winner 方式**（Last-Write-Wins）か、**マージ方式**か → フェーズ2設計時に確定
- **PartEvent は全端末から全件集約**（追記専用なのでマージが単純）
- **写真ファイルの同期**はPartとは別経路で扱う（転送容量の都合）
- **時刻はサーバー時刻ではなく端末時刻**。端末時刻ズレの扱いは要検討

---

## 8. 補足仕様（確定済み）

- **Actor識別**: フェーズ1は「端末一意ID（identifierForVendor）」+「ユーザー名（初回入力）」のペアで識別（D-021）
- **写真の圧縮設定**: JPEG品質80%、長辺1600pxにリサイズ（D-022）
- **OCR元画像の扱い**: 登録時のOCR対象画像を自動で1枚目の写真として保存。2枚目は任意で追加撮影（D-023）
- **削除機能**: 物理削除なし。論理削除のみ（`isDeleted` フラグで非表示化、PartEvent は残す）（D-024）
- **備考欄の最大文字数**: 500文字（D-025）
