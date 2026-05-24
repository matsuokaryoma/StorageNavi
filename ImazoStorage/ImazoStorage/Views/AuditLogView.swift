import SwiftUI
import SwiftData

// 監査ログ閲覧画面
// PartEvent を新しい順に一覧表示する。イベント種別でフィルタリングも可能
struct AuditLogView: View {

    // 全イベントを新しい順で取得（append-only なので削除フィルタ不要）
    @Query(sort: \PartEvent.occurredAt, order: .reverse)
    private var allEvents: [PartEvent]

    // フィルタ: nil = すべて表示
    @State private var filterType: PartEventType? = nil

    private var visibleEvents: [PartEvent] {
        guard let f = filterType else { return allEvents }
        return allEvents.filter { $0.eventType == f }
    }

    var body: some View {
        Group {
            if visibleEvents.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(visibleEvents) { event in
                        AuditLogRow(event: event)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("監査ログ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
    }

    // MARK: - 空状態

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("ログがありません")
                .font(.title3.bold())
            if filterType != nil {
                Text("フィルタを解除すると表示されることがあります")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - フィルタメニュー

    private var filterMenu: some View {
        Menu {
            Button {
                filterType = nil
            } label: {
                Label("すべて表示", systemImage: filterType == nil ? "checkmark" : "line.3.horizontal.decrease")
            }

            Divider()

            ForEach(PartEventType.allCases, id: \.self) { type in
                Button {
                    filterType = filterType == type ? nil : type
                } label: {
                    Label(type.displayName, systemImage: filterType == type ? "checkmark" : eventIcon(type))
                }
            }
        } label: {
            Image(systemName: filterType == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.body)
        }
    }

    private func eventIcon(_ type: PartEventType) -> String {
        switch type {
        case .registered:        return "plus.circle"
        case .edited:            return "pencil"
        case .markedAsUsed:      return "checkmark.circle"
        case .returnedToStorage: return "arrow.uturn.left"
        case .locationUpdated:   return "location"
        case .photoAdded:        return "photo.badge.plus"
        case .photoReplaced:     return "photo.badge.arrow.down"
        case .photoRemoved:      return "photo.badge.minus"
        case .softDeleted:       return "trash"
        }
    }
}

// MARK: - 1行分のセル

private struct AuditLogRow: View {
    let event: PartEvent

    // 日付フォーマッタ（表示は「4/26 14:32」形式）
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M/d HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1行目: イベント種別バッジ + パーツ名
            HStack(spacing: 8) {
                EventBadge(eventType: event.eventType)
                Text(event.partNameSnapshot)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                Text(Self.dateFormatter.string(from: event.occurredAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 2行目: 操作者名
            HStack(spacing: 4) {
                Image(systemName: "person")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(event.actorName.isEmpty ? "（名前未設定）" : event.actorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // changesJSON があれば変更内容をパースして表示
            if let json = event.changesJSON, !json.isEmpty,
               let changes = parseChanges(json) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(changes, id: \.field) { change in
                        HStack(alignment: .top, spacing: 4) {
                            Text(change.field)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 40, alignment: .leading)
                            Text("\(change.before) → \(change.after)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    // changesJSON のパース（フィールド変更ログ用）
    private struct FieldChange: Codable {
        let field: String
        let before: String
        let after: String
    }

    private func parseChanges(_ json: String) -> [FieldChange]? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([FieldChange].self, from: data)
    }
}

// MARK: - イベント種別バッジ

private struct EventBadge: View {
    let eventType: PartEventType

    var body: some View {
        Text(eventType.displayName)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15), in: Capsule())
            .foregroundStyle(badgeColor)
    }

    private var badgeColor: Color {
        switch eventType {
        case .registered:        return .blue
        case .edited:            return .orange
        case .markedAsUsed:      return .green
        case .returnedToStorage: return .cyan
        case .locationUpdated:   return .purple
        case .photoAdded, .photoReplaced, .photoRemoved: return .indigo
        case .softDeleted:       return .red
        }
    }
}

// MARK: - PartEventType を ForEach で使うために CaseIterable に準拠

extension PartEventType: CaseIterable {
    static var allCases: [PartEventType] {
        [.registered, .edited, .markedAsUsed, .returnedToStorage,
         .locationUpdated, .photoAdded, .photoReplaced, .photoRemoved, .softDeleted]
    }
}

#Preview {
    NavigationStack {
        AuditLogView()
    }
    .modelContainer(for: [Part.self, PartEvent.self], inMemory: true)
}
