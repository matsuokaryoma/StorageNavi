import SwiftUI
import SwiftData

// 検索結果一覧画面（D-015: 件数表示 / 0件時メッセージ）
struct SearchResultsView: View {

    let query: String

    @Environment(\.modelContext) private var modelContext
    @State private var results: [Part] = []
    @State private var showUsed: Bool
    @State private var searchInOCR: Bool

    init(query: String, initialShowUsed: Bool = false, initialSearchInOCR: Bool = false) {
        self.query = query
        _showUsed    = State(initialValue: initialShowUsed)
        _searchInOCR = State(initialValue: initialSearchInOCR)
    }

    var body: some View {
        Group {
            if results.isEmpty {
                // 0件表示（D-015）
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("該当するパーツはありません")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(query.trimmingCharacters(in: .whitespaces).isEmpty
                         ? "登録されているパーツはありません"
                         : "「\(query)」に一致するパーツが見つかりませんでした")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { part in
                    NavigationLink {
                        PartDetailView(mode: .view, existingPart: part)
                    } label: {
                        PartRowView(part: part)
                    }
                }
            }
        }
        // ○件ヒット（D-015）
        .navigationTitle("\(results.count)件ヒット")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    // 使用済みの表示切替（D-006）
                    Button {
                        showUsed.toggle()
                    } label: {
                        Label(
                            showUsed ? "保管中のみ表示" : "使用済みも表示",
                            systemImage: showUsed ? "eye.slash" : "eye"
                        )
                    }

                    // OCRテキスト検索の切替
                    Button {
                        searchInOCR.toggle()
                    } label: {
                        Label(
                            searchInOCR ? "パーツ名のみ検索" : "OCRテキストも検索",
                            systemImage: searchInOCR ? "text.magnifyingglass" : "doc.text.magnifyingglass"
                        )
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle\(showUsed || searchInOCR ? ".fill" : "")")
                }
            }
        }
        .onAppear { fetchResults() }
        .onChange(of: showUsed)    { fetchResults() }
        .onChange(of: searchInOCR) { fetchResults() }
    }

    // MARK: - SwiftData で検索（D-005）
    private func fetchResults() {
        let q           = query.trimmingCharacters(in: .whitespaces)
        let includeUsed = showUsed
        let includeOCR  = searchInOCR

        // 削除済みを除いた全件を取得し、Swift側でフィルタする
        // （OCR検索は Optional 含む複合条件のため #Predicate より in-memory が安全）
        var descriptor = FetchDescriptor<Part>(
            predicate: #Predicate<Part> { !$0.isDeleted },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1000

        var fetched = (try? modelContext.fetch(descriptor)) ?? []

        // クエリがある場合はパーツ名で部分一致、OCR検索ONなら ocrRawText も対象
        if !q.isEmpty {
            fetched = fetched.filter { part in
                part.name.localizedStandardContains(q)
                || (includeOCR && (part.ocrRawText ?? "").localizedStandardContains(q))
            }
        }

        results = includeUsed ? fetched : fetched.filter { $0.status == .inStorage }
    }
}

// MARK: - 検索結果の1行表示
struct PartRowView: View {
    let part: Part

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(part.name)
                .font(.body.bold())

            HStack(spacing: 8) {
                // ステータスバッジ
                Text(part.status.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(part.status == .inStorage ? .green : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (part.status == .inStorage ? Color.green : Color.secondary).opacity(0.15),
                        in: Capsule()
                    )

                Text("登録: \(part.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
