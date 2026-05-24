import AVFoundation
import UIKit
import CoreLocation

// QRコードスキャン画面用 ViewModel
// カメラのライブ映像からQRコードをリアルタイムに検出し、
// 検出と同時に写真撮影とGPS取得を行い、PartDetailView へ遷移するデータを準備する
@MainActor
final class QRScannerViewModel: NSObject, ObservableObject {

    // MARK: - カメラセッション

    // CameraPreview に渡すセッション（映像プレビュー用）
    let session = AVCaptureSession()

    // QRコードをリアルタイム検出するための出力
    private let metadataOutput = AVCaptureMetadataOutput()

    // QRコード検出時に静止画を撮るための出力
    private let photoOutput = AVCapturePhotoOutput()

    // MARK: - 画面状態

    // QRコード検出後の写真撮影・GPS取得中は true（インジケータ表示用）
    @Published var isProcessing = false

    // 全データ揃ったら true にして PartDetailView へ遷移
    @Published var isReadyToNavigate = false

    // エラーメッセージ。nil のときはエラーなし
    @Published var errorMessage: String?

    // MARK: - PartDetailView へ渡すデータ

    var qrCodeText: String = ""       // 検出したQRコードの値（パーツ名の初期値として使用）
    var capturedImage: UIImage?       // QRコード検出時に撮影した静止画（証跡写真）
    var capturedLocation: CLLocation? // QRコード検出時のGPS位置

    // MARK: - 内部サービス

    private let locationService = LocationService()

    // カメラ起動時にGPS先読みを開始するタスク（撮影完了までに取得が終わるように）
    private var locationPrefetchTask: Task<CLLocation, Error>?

    // 写真撮影完了を async/await で受け取るための継続
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    // 最初のQRコード検出だけ処理するフラグ（同一フレームの多重検出防止）
    private var hasDetected = false

    // MARK: - セッション管理

    // 画面表示時に呼ぶ。カメラ起動と同時にGPS先読みを開始する
    // 登録完了後に戻ってきたときも呼ばれるため、ここで状態を毎回リセットする
    func startSession() {
        hasDetected = false
        isProcessing = false
        isReadyToNavigate = false
        qrCodeText = ""
        capturedImage = nil
        capturedLocation = nil
        errorMessage = nil

        Task.detached { [weak self] in
            guard let self else { return }
            await self.configureSession()
            await self.session.startRunning()
        }
        startLocationPrefetch()
    }

    // 画面から離れる時に呼ぶ
    func stopSession() {
        locationPrefetchTask?.cancel()
        locationPrefetchTask = nil
        Task.detached { [weak self] in
            await self?.session.stopRunning()
        }
    }

    // GPS先読みを開始する（二重起動しない）
    private func startLocationPrefetch() {
        guard locationPrefetchTask == nil else { return }
        locationPrefetchTask = Task {
            try await locationService.currentLocation()
        }
    }

    // カメラセッションの初期設定
    private func configureSession() async {
        // 既に設定済みなら再設定不要（画面を戻って再表示したとき）
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // 背面カメラを取得して入力に追加
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            errorMessage = "カメラを起動できませんでした"
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // QR検出用のメタデータ出力を追加
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
        }

        // 証跡写真撮影用の出力を追加
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()

        // メタデータタイプは commitConfiguration 後に設定する必要がある
        metadataOutput.metadataObjectTypes = [.qr]
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
    }

    // MARK: - QRコード検出処理

    // メタデータデリゲートからQRコード値が届いたときに呼ばれる
    func handleDetection(_ value: String) {
        // 既に処理中または検出済みなら無視（多重検出防止）
        guard !hasDetected, !isProcessing else { return }
        hasDetected = true
        isProcessing = true
        qrCodeText = value

        // 触覚フィードバックで検出成功を伝える
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            do {
                // 1. 静止画を撮影（証跡写真として保存）
                let image = try await capturePhoto()
                capturedImage = image

                // 2. GPS取得（先読みタスクが終わっていれば即返る）
                if locationPrefetchTask == nil { startLocationPrefetch() }
                capturedLocation = try await locationPrefetchTask!.value
                locationPrefetchTask = nil

                // 3. 遷移トリガー
                isReadyToNavigate = true
            } catch {
                // エラー時は検出フラグをリセットして再スキャン可能にする
                hasDetected = false
                errorMessage = "処理中にエラーが発生しました: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }

    // AVCapturePhotoOutput で静止画を1枚撮影して UIImage を返す（async/await）
    private func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate（QRコード検出コールバック）

extension QRScannerViewModel: AVCaptureMetadataOutputObjectsDelegate {

    // QRコードを含むメタデータが検出されると OS から呼ばれる
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                     didOutput metadataObjects: [AVMetadataObject],
                                     from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        // デリゲートは main キューで受け取るが、@MainActor への明示的なホップで安全に処理
        Task { @MainActor in self.handleDetection(value) }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate（写真撮影コールバック）

extension QRScannerViewModel: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                  didFinishProcessingPhoto photo: AVCapturePhoto,
                                  error: Error?) {
        if let error {
            Task { @MainActor in
                self.photoContinuation?.resume(throwing: error)
                self.photoContinuation = nil
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                self.photoContinuation?.resume(throwing: CameraError.invalidImageData)
                self.photoContinuation = nil
            }
            return
        }

        Task { @MainActor in
            self.photoContinuation?.resume(returning: image)
            self.photoContinuation = nil
        }
    }
}
