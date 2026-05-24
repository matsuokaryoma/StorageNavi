import CoreLocation

// GPS取得時のエラー定義
enum LocationError: LocalizedError {
    case timedOut

    var errorDescription: String? {
        switch self {
        case .timedOut: return "位置情報の取得がタイムアウトしました（精度不足）"
        }
    }
}

// GPS位置情報を取得するサービス
// CLLocationManager を内部で管理し、現在地を async/await で返す
@MainActor
final class LocationService: NSObject, ObservableObject {

    private let manager = CLLocationManager()

    // 最後に取得できた位置情報（nil = まだ取得できていない）
    @Published var lastLocation: CLLocation?

    // 権限ステータス
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // 位置取得完了を待つための仕組み
    private var continuation: CheckedContinuation<CLLocation, Error>?

    // 許容する最大水平誤差（メートル）
    // 15m以内: GPS衛星捕捉後に素早く達成できる精度。置場の特定に十分
    private let acceptableAccuracy: Double = 15.0

    // OSキャッシュを有効とみなす最大経過時間（秒）
    private let cacheMaxAge: TimeInterval = 30.0

    override init() {
        super.init()
        manager.delegate = self
        // kCLLocationAccuracyBest（±5m）はGPS衛星が必要で遅い。
        // NearestTenMeters（±10m）ならWi-Fi/基地局で素早く取得できる
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        authorizationStatus = manager.authorizationStatus
    }

    // 位置情報の利用許可をユーザーに求める（初回のみダイアログが出る）
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // 現在地を取得して返す（async/await）
    func currentLocation() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        // OSキャッシュが新鮮かつ許容精度内なら即座に返す（2回目以降はほぼ瞬時）
        if let cached = manager.location,
           abs(cached.timestamp.timeIntervalSinceNow) < cacheMaxAge,
           cached.horizontalAccuracy > 0,
           cached.horizontalAccuracy <= acceptableAccuracy {
            return cached
        }

        // キャッシュが使えない場合: 連続更新を開始し、
        // 許容精度を満たした最初の位置情報が届いた時点で返す
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.startUpdatingLocation()

            // 10秒以内に精度が出なければタイムアウト
            // 屋内・電波弱い環境でも固まらないようにするため
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await Task.sleep(for: .seconds(10))
                } catch {
                    return // キャンセル時は何もしない
                }
                guard let cont = self.continuation else { return }
                self.manager.stopUpdatingLocation()
                // 精度を問わず取得済みの位置を使う。なければエラー
                if let loc = self.manager.location {
                    cont.resume(returning: loc)
                } else {
                    cont.resume(throwing: LocationError.timedOut)
                }
                self.continuation = nil
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {

    // OS から位置情報が届いたときに呼ばれる（startUpdatingLocation で連続的に届く）
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = location

            // continuation が待っていて、かつ許容精度を満たしていれば応答して更新を停止
            guard let cont = self.continuation,
                  location.horizontalAccuracy > 0,
                  location.horizontalAccuracy <= self.acceptableAccuracy else { return }

            manager.stopUpdatingLocation()
            cont.resume(returning: location)
            self.continuation = nil
        }
    }

    // 位置取得に失敗したときに呼ばれる
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            manager.stopUpdatingLocation()
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }

    // 権限ステータスが変わったときに呼ばれる
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}
