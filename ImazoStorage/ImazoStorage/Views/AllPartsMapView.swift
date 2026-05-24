import SwiftUI
import SwiftData
import MapKit

// 全パーツを地図に表示する画面
struct AllPartsMapView: View {

    // 論理削除されていない全パーツを更新日時の降順で取得
    @Query(
        filter: #Predicate<Part> { !$0.isDeleted },
        sort: \Part.updatedAt, order: .reverse
    )
    private var parts: [Part]

    // カメラ位置: パーツがなければ日本中心付近を表示。onAppear で全パーツに自動フィットする
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )

    // タップしたパーツ → 詳細画面への遷移
    @State private var selectedPart: Part? = nil
    @State private var isShowingDetail   = false

    // 使用済みを地図に表示するかどうか
    @State private var showUsed = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(visibleParts) { part in
                    Annotation(part.name, coordinate: part.coordinate) {
                        PartPin(status: part.status)
                            .onTapGesture {
                                selectedPart = part
                                isShowingDetail = true
                            }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))

            // 使用済み表示トグル（右下）
            toggleButton
                .padding(16)
        }
        .navigationTitle("全パーツ地図")
        .navigationBarTitleDisplayMode(.inline)
        // パーツが1件以上あれば自動でフィット
        .onAppear { fitCamera() }
        // 詳細画面への遷移
        .navigationDestination(isPresented: $isShowingDetail) {
            if let part = selectedPart {
                PartDetailView(mode: .view, existingPart: part)
            }
        }
    }

    // MARK: - 表示対象パーツ

    private var visibleParts: [Part] {
        showUsed ? parts : parts.filter { $0.status == .inStorage }
    }

    // MARK: - カメラを全パーツに合わせる

    private func fitCamera() {
        let targets = visibleParts
        guard !targets.isEmpty else { return }

        if targets.count == 1 {
            // 1件のみ: その位置を中心に適切なズームで表示
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: targets[0].coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                )
            )
            return
        }

        let lats = targets.map { $0.latitude }
        let lons = targets.map { $0.longitude }
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!

        let center = CLLocationCoordinate2D(
            latitude:  (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // パーツが密集していても十分見えるように余白を 1.4 倍確保
        let span = MKCoordinateSpan(
            latitudeDelta:  max((maxLat - minLat) * 1.4, 0.002),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.002)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    // MARK: - 使用済みトグルボタン

    private var toggleButton: some View {
        Button {
            showUsed.toggle()
            fitCamera()
        } label: {
            Label(
                showUsed ? "使用済みを非表示" : "使用済みも表示",
                systemImage: showUsed ? "archivebox.fill" : "archivebox"
            )
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ピンのビュー（保管中=青, 使用済み=グレー）

private struct PartPin: View {
    let status: PartStatus

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor.opacity(0.2))
                .frame(width: 36, height: 36)
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 18))
                .foregroundStyle(pinColor)
        }
    }

    private var pinColor: Color {
        status == .inStorage ? .blue : .gray
    }
}

// MARK: - Part に座標プロパティを追加

private extension Part {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

#Preview {
    NavigationStack {
        AllPartsMapView()
    }
    .modelContainer(for: [Part.self, PartEvent.self], inMemory: true)
}
