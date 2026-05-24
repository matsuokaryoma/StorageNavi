import SwiftUI
import SwiftData

// 長期保管パーツの自動アーカイブ確認シート
// 6ヶ月以上更新されていない保管中パーツを一覧し、使用済みにするか確認する
struct ArchiveSuggestionView: View {

    let parts: [Part]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @EnvironmentObject private var userSettings: UserSettingsService

    // 使用済みにする対象（デフォルトは全選択）
    @State private var selectedIDs: Set<UUID>
    @State private var isShowingConfirm = false

    init(parts: [Part]) {
        self.parts = parts
        _selectedIDs = State(initialValue: Set(parts.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── 説明文 ──────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("以下のパーツは6ヶ月以上更新されていません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("使用済みにする場合はチェックを入れて確認してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))

                // ── パーツ一覧 ──────────────────────────────
                List {
                    ForEach(parts) { part in
                        ArchivePartRow(
                            part: part,
                            isSelected: selectedIDs.contains(part.id)
                        ) {
                            if selectedIDs.contains(part.id) {
                                selectedIDs.remove(part.id)
                            } else {
                                selectedIDs.insert(part.id)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // ── 確認ボタン ──────────────────────────────
                VStack(spacing: 12) {
                    Button {
                        isShowingConfirm = true
                    } label: {
                        Text("使用済みにする（\(selectedIDs.count)件）")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedIDs.isEmpty)

                    Button("後で確認する") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.background)
            }
            .navigationTitle("長期保管パーツの確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog(
                "選択した\(selectedIDs.count)件を使用済みにします。\nこの操作は取り消せません。",
                isPresented: $isShowingConfirm,
                titleVisibility: .visible
            ) {
                Button("使用済みにする", role: .destructive) {
                    archiveSelected()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    // MARK: - 使用済みに変更する

    private func archiveSelected() {
        let now      = Date()
        let actor    = userSettings.userName
        let deviceId = userSettings.deviceId

        for part in parts where selectedIDs.contains(part.id) {
            part.status    = .used
            part.usedAt    = now
            part.updatedAt = now
            part.updatedBy = actor

            let event = PartEvent(
                partId: part.id,
                partNameSnapshot: part.name,
                eventType: .markedAsUsed,
                actorId: deviceId,
                actorName: actor,
                deviceId: deviceId,
                occurredAt: now
            )
            modelContext.insert(event)
        }

        dismiss()
    }
}

// MARK: - 1行分のセル

private struct ArchivePartRow: View {
    let part: Part
    let isSelected: Bool
    let onToggle: () -> Void

    // 最終更新からの経過時間を日本語で表示
    private var elapsedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: part.updatedAt, relativeTo: Date())
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .secondary)

                VStack(alignment: .leading, spacing: 3) {
                    Text(part.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("最終更新: \(elapsedText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // タップ領域を確保（手袋を想定）
        .frame(minHeight: 48)
    }
}

#Preview {
    let parts: [Part] = []
    return ArchiveSuggestionView(parts: parts)
        .environmentObject(UserSettingsService())
        .modelContainer(for: [Part.self, PartEvent.self], inMemory: true)
}
