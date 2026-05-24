import SwiftUI

// 検索条件入力画面
// テキスト入力 または カメラOCRスキャン → SearchResultsView へ遷移
struct SearchView: View {

    @State private var searchText = ""
    @State private var shouldNavigate = false
    @State private var isShowingCameraSheet = false
    @State private var showUsed = false
    @State private var searchInOCR = false

    var body: some View {
        VStack(spacing: 0) {
            // ── 検索フィールド ─────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("パーツ名を入力", text: $searchText)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit { shouldNavigate = true }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 20)

            // ── カメラスキャンで検索 ───────────────────────
            Button {
                isShowingCameraSheet = true
            } label: {
                Label("カメラでスキャンして検索", systemImage: "camera.fill")
                    .font(.body.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.top, 16)

            // ── 検索オプション ─────────────────────────────
            VStack(spacing: 0) {
                Toggle("使用済みも表示する", isOn: $showUsed)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                Divider().padding(.leading)
                Toggle("OCRテキストも検索する", isOn: $searchInOCR)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 16)

            // ── 検索ボタン ─────────────────────────────────
            Button {
                shouldNavigate = true
            } label: {
                Text("検索する")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.top, 12)

            Spacer()
        }
        .navigationTitle("データを探す")
        .navigationBarTitleDisplayMode(.large)
        // テキスト検索 → 結果一覧へ
        .navigationDestination(isPresented: $shouldNavigate) {
            SearchResultsView(query: searchText, initialShowUsed: showUsed, initialSearchInOCR: searchInOCR)
        }
        // カメラスキャン → OCR結果をテキストにセットして検索へ
        .sheet(isPresented: $isShowingCameraSheet) {
            NavigationStack {
                CameraOCRView(onSearchComplete: { recognizedText in
                    searchText = recognizedText
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        shouldNavigate = true
                    }
                })

                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { isShowingCameraSheet = false }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
