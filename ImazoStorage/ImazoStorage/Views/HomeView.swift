import SwiftUI

// ホーム画面: 「登録する」「データを探す」の2つの入口を持つ起点画面
struct HomeView: View {
    @EnvironmentObject private var userSettings: UserSettingsService
    @State private var isShowingSettings = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {

                // ── ロゴエリア ──────────────────────────────
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    Text("IMAZO置場管理")
                        .font(.title.bold())

                    Text("鉄板パーツの置場を記録・検索")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // ── アクションボタン ────────────────────────
                VStack(spacing: 16) {
                    NavigationLink {
                        CameraOCRView()
                    } label: {
                        Label("登録する（OCR）", systemImage: "camera.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.borderedProminent)

                    NavigationLink {
                        QRScannerView()
                    } label: {
                        Label("登録する（QRコード）", systemImage: "qrcode.viewfinder")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.borderedProminent)

                    NavigationLink {
                        SearchView()
                    } label: {
                        Label("データを探す", systemImage: "magnifyingglass")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        AllPartsMapView()
                    } label: {
                        Label("地図で見る", systemImage: "map")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        AuditLogView()
                    } label: {
                        Label("監査ログ", systemImage: "doc.text.magnifyingglass")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }

            // ── 設定ボタン（右上）──────────────────────────
            // navigationBarHidden(true) だと toolbar が隠れるためビュー内に直接配置
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(userSettings)
            }
        }
    }
}

// 未実装画面の仮置き（各画面を実装したら差し替える）
struct PlaceholderView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.bold())
            Text("実装中")
                .foregroundStyle(.secondary)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
