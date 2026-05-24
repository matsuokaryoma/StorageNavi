import SwiftUI
import SwiftData

// 設定画面（ユーザー名の変更など）
struct SettingsView: View {

    @EnvironmentObject private var userSettings: UserSettingsService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var inputName: String = ""

    // CSV エクスポート
    @State private var exportURL: URL?          = nil
    @State private var isShowingShareSheet      = false
    @State private var isExporting              = false
    @State private var exportErrorMessage: String? = nil

    var body: some View {
        Form {
                Section {
                    TextField("名前を入力", text: $inputName)
                        .autocorrectionDisabled()
                } header: {
                    Text("ユーザー名")
                } footer: {
                    Text("操作の記録（誰が登録・更新したか）に使われます。")
                }

                Section("端末情報") {
                    // 端末IDは先頭8文字だけ表示（デバッグ・確認用）
                    LabeledContent("端末ID") {
                        Text(String(userSettings.deviceId.prefix(8)) + "…")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("データ管理") {
                    Button {
                        exportCSV()
                    } label: {
                        HStack {
                            Label("CSVエクスポート", systemImage: "square.and.arrow.up")
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                    }
                    .disabled(isExporting)
                }

                #if DEBUG
                Section("開発用") {
                    Button("テストデータを追加") {
                        insertSampleData()
                    }
                    .foregroundStyle(.orange)
                }
                #endif
            }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    let name = inputName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty {
                        userSettings.userName = name
                    }
                    dismiss()
                }
                .disabled(inputName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
        }
        .onAppear {
            inputName = userSettings.userName
        }
        // CSV エクスポート: ファイルが準備できたらシェアシートを開く
        .sheet(isPresented: $isShowingShareSheet, onDismiss: { exportURL = nil }) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
                    .ignoresSafeArea()
            }
        }
        // エクスポートエラー
        .alert("エクスポートに失敗しました", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK") { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }

    // MARK: - CSV エクスポート

    private func exportCSV() {
        isExporting = true

        // 論理削除されていない全パーツを取得（削除済みは含めない）
        var descriptor = FetchDescriptor<Part>(
            predicate: #Predicate<Part> { !$0.isDeleted },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10_000

        do {
            let parts = try modelContext.fetch(descriptor)
            let url   = try CSVExportService.shared.export(parts: parts)
            exportURL         = url
            isShowingShareSheet = true
        } catch {
            exportErrorMessage = error.localizedDescription
        }

        isExporting = false
    }

    #if DEBUG
    // テストデータを追加する（開発・動作確認用）
    // 東京都心付近（35.68°N, 139.77°E）の架空座標を使用
    private func insertSampleData() {
        let actor    = userSettings.userName.isEmpty ? "テストユーザー" : userSettings.userName
        let deviceId = userSettings.deviceId
        let now      = Date()

        struct Sample {
            let name: String; let status: PartStatus
            let lat: Double; let lon: Double
            let notes: String?; let daysAgo: Double
        }
        let samples: [Sample] = [
            Sample(name: "アイテム-A12",   status: .inStorage, lat: 35.6812, lon: 139.7671, notes: "確認済み",           daysAgo:  3),
            Sample(name: "アイテム-B7",    status: .inStorage, lat: 35.6798, lon: 139.7688, notes: nil,                  daysAgo:  1),
            Sample(name: "アイテム-C3",    status: .used,      lat: 35.6825, lon: 139.7645, notes: "搬出済み",           daysAgo: 10),
            Sample(name: "アイテム-D9",    status: .inStorage, lat: 35.6781, lon: 139.7702, notes: "サイズ: 200×90×9mm", daysAgo:  5),
            Sample(name: "アイテム-E5",    status: .inStorage, lat: 35.6834, lon: 139.7658, notes: nil,                  daysAgo:  2),
            Sample(name: "アイテム-F1",    status: .used,      lat: 35.6759, lon: 139.7631, notes: "使用完了",           daysAgo: 15),
        ]

        for s in samples {
            let createdAt = now.addingTimeInterval(-s.daysAgo * 86400)
            let usedAt    = s.status == .used ? createdAt.addingTimeInterval(86400) : nil

            let part = Part(
                name: s.name,
                status: s.status,
                latitude: s.lat,
                longitude: s.lon,
                locationAccuracy: Double.random(in: 3...12),
                notes: s.notes,
                createdAt: createdAt,
                createdBy: actor,
                updatedAt: createdAt,
                updatedBy: actor,
                usedAt: usedAt
            )
            modelContext.insert(part)

            let event = PartEvent(
                partId: part.id,
                partNameSnapshot: part.name,
                eventType: .registered,
                actorId: deviceId,
                actorName: actor,
                deviceId: deviceId,
                occurredAt: createdAt
            )
            modelContext.insert(event)
        }
    }
    #endif
}

// MARK: - UIActivityViewController ラッパー

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(UserSettingsService())
    }
}
