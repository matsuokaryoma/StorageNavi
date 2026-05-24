import SwiftUI
import SwiftData

// アプリのルートビュー
// iPhone（compact）: NavigationStack ベースの既存レイアウト
// iPad（regular）  : NavigationSplitView でサイドバー＋詳細列の2カラムレイアウト
struct ContentView: View {

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext)        private var modelContext
    @EnvironmentObject private var userSettings: UserSettingsService

    // 自動アーカイブ候補として見つかったパーツ
    @State private var archiveCandidates: [Part] = []
    @State private var isShowingArchiveSuggestion = false

    var body: some View {
        Group {
            if sizeClass == .regular {
                IPadRootView()
            } else {
                NavigationStack {
                    HomeView()
                }
            }
        }
        .onAppear { checkForLongStoredParts() }
        .sheet(isPresented: $isShowingArchiveSuggestion) {
            ArchiveSuggestionView(parts: archiveCandidates)
                .environmentObject(userSettings)
        }
    }

    // MARK: - 6ヶ月以上保管中のパーツを確認（1日1回）

    private func checkForLongStoredParts() {
        // 今日すでにチェック済みならスキップ
        if let last = userSettings.lastArchiveCheckDate,
           Calendar.current.isDateInToday(last) { return }

        userSettings.lastArchiveCheckDate = Date()

        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        let descriptor = FetchDescriptor<Part>(
            predicate: #Predicate<Part> {
                !$0.isDeleted
                && $0.statusRaw == "inStorage"
                && $0.updatedAt < sixMonthsAgo
            },
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        let candidates = (try? modelContext.fetch(descriptor)) ?? []
        guard !candidates.isEmpty else { return }

        archiveCandidates = candidates
        isShowingArchiveSuggestion = true
    }
}

// MARK: - iPad レイアウト

// iPad サイドバーの選択項目
private enum SidebarItem: Hashable {
    case search
    case map
    case auditLog
}

private struct IPadRootView: View {

    @EnvironmentObject private var userSettings: UserSettingsService
    @State private var isShowingCamera   = false
    @State private var isShowingSettings = false
    @State private var selectedItem: SidebarItem? = .search

    var body: some View {
        NavigationSplitView {
            // ── サイドバー ──────────────────────────────────
            List(selection: $selectedItem) {
                Label("データを探す", systemImage: "magnifyingglass")
                    .frame(height: 44)
                    .tag(SidebarItem.search)

                Label("地図で見る", systemImage: "map")
                    .frame(height: 44)
                    .tag(SidebarItem.map)

                Label("監査ログ", systemImage: "doc.text.magnifyingglass")
                    .frame(height: 44)
                    .tag(SidebarItem.auditLog)
            }
            .listStyle(.sidebar)
            .navigationTitle("置場ナビ")
            .navigationBarTitleDisplayMode(.inline)
            // 登録ボタン（常にサイドバー上部に固定表示）
            .safeAreaInset(edge: .top, spacing: 0) {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("登録する", systemImage: "camera.fill")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.background)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
            }

        } detail: {
            // ── 詳細列: サイドバー選択に応じて切り替え ──────
            NavigationStack {
                switch selectedItem {
                case .map:
                    AllPartsMapView()
                case .auditLog:
                    AuditLogView()
                default:
                    SearchView()
                }
            }
        }
        // 登録カメラ（常にフルスクリーンで開く）
        .fullScreenCover(isPresented: $isShowingCamera) {
            NavigationStack {
                CameraOCRView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { isShowingCamera = false }
                        }
                    }
            }
        }
        // 設定（シート）
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(userSettings)
        }
    }
}

#Preview {
    ContentView()
}
