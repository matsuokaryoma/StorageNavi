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
    // 今治造船所周辺（34.07°N, 133.00°E）の架空座標を使用
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
            Sample(name: "H鋼-A12",        status: .inStorage, lat: 34.0712, lon: 133.0021, notes: "加工済み・面取り完了",    daysAgo:  3),
            Sample(name: "鉄板-B7",        status: .inStorage, lat: 34.0698, lon: 132.9988, notes: nil,                     daysAgo:  1),
            Sample(name: "フレーム-C3",    status: .used,      lat: 34.0725, lon: 133.0045, notes: "第3船台へ搬入済み",      daysAgo: 10),
            Sample(name: "Uチャンネル-D9", status: .inStorage, lat: 34.0681, lon: 132.9972, notes: "サイズ: 200×90×9mm",    daysAgo:  5),
            Sample(name: "ブラケット-E5",  status: .inStorage, lat: 34.0734, lon: 133.0008, notes: nil,                     daysAgo:  2),
            Sample(name: "プレート-F1",    status: .used,      lat: 34.0659, lon: 132.9961, notes: "船殻溶接完了",           daysAgo: 15),
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
