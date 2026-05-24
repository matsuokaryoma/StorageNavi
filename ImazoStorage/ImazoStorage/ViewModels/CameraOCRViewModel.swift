import AVFoundation
import UIKit
import CoreLocation

// カメラ撮影 → OCR → GPS取得 の一連の流れを管理する ViewModel
@MainActor
final class CameraOCRViewModel: NSObject, ObservableObject {

    // MARK: - 状態

    // カメラのプレビューに使うセッション（CameraPreview に渡す）
    let session = AVCaptureSession()

    // 写真を実際に撮るためのオブジェクト
    private let photoOutput = AVCapturePhotoOutput()

    // MARK: - 画面に表示する状態

    // OCR が終わったら true → PartDetailView へ遷移するトリガー
    @Published var isReadyToNavigate = false

    // 処理中（カメラ起動中・撮影中・OCR中）は true にして UI でインジケータを表示
    @Published var isProcessing = false

    // エラーメッセージ。nil のときはエラーなし
    @Published var errorMessage: String?

    // MARK: - 次の画面に渡すデータ

    // OCR で認識したテキスト（複数行を改行でまとめたもの）
    var recognizedText: String = ""

    // OCR 前の生テキスト（誤認識分析用に保持）
    var ocrRawText: String = ""

    // 撮影した元画像
    var capturedImage: UIImage?

    // GPS で取得した位置情報
    var capturedLocation: CLLocation?

    // MARK: - 内部サービス

    private let ocrService = OCRService()
    private let locationService = LocationService()

    // 検索モード用コールバック。nil なら登録モード、セットされていれば検索モード
    var searchCompletionHandler: ((String) -> Void)?

    // 写真撮影完了を待つための仕組み
    private var photoContinuation: CheckedContinuation<UIImage, Error>?

    // 位置情報の先読みタスク（カメラ起動時に開始し、撮影完了までに取得を終わらせる）
    private var locationPrefetchTask: Task<CLLocation, Error>?

    // MARK: - カメラ初期化

    // カメラセッションをバックグラウンドで起動する
    func startSession() {
        Task.detached { [weak self] in
            guard let self else { return }
            await self.configureSession()
            await self.session.startRunning()
        }
        // 登録モードのみ: カメラ起動と同時にGPSの先読みを開始する
        if searchCompletionHandler == nil {
            startLocationPrefetch()
        }
    }

    // カメラセッションを止める（画面を離れるときに呼ぶ）
    func stopSession() {
        locationPrefetchTask?.cancel()
        locationPrefetchTask = nil
        Task.detached { [weak self] in
            await self?.session.stopRunning()
        }
    }

    // 位置情報の先読みを開始する（二重起動しない）
    private func startLocationPrefetch() {
        guard locationPrefetchTask == nil else { return }
        locationPrefetchTask = Task {
            try await locationService.currentLocation()
        }
    }

    // AVCaptureSession にカメラ入力と写真出力を設定する
    private func configureSession() async {
        // 既に入力が追加済みなら再設定不要（画面を戻って再表示したとき）
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // 背面カメラを取得
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            await MainActor.run {
                self.errorMessage = "カメラを起動できませんでした"
            }
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        // 写真出力を追加
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    // MARK: - 撮影〜OCR〜GPS

    // シャッターボタンが押されたときに呼ぶ
    func captureAndProcess() {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                // 1. 写真を撮る
                let image = try await capturePhoto()
                capturedImage = image

                if let handler = searchCompletionHandler {
                    // 検索モード: OCRのみ。GPS不要なのでそのままコールバック
                    let result = try await ocrService.recognizeFull(image: image)
                    ocrRawText     = ocrService.join(lines: result.allLines)
                    recognizedText = result.primaryText
                    handler(result.primaryText)
                } else {
                    // 登録モード:
                    // GPS は startSession() 時点で先読み済みのはず。
                    // 万が一タスクがなければここで起動する（二重呼び出しを防ぐため Task 経由）
                    if locationPrefetchTask == nil { startLocationPrefetch() }
                    let gpsTask = locationPrefetchTask!

                    // OCR を非同期で開始（GPS と並列）
                    async let ocrResult = ocrService.recognizeFull(image: image)

                    let result = try await ocrResult
                    recognizedText = result.primaryText
                    ocrRawText     = ocrService.join(lines: result.allLines)

                    // 先読み済みなら即返る。まだなら残り時間だけ待つ
                    capturedLocation     = try await gpsTask.value
                    locationPrefetchTask = nil  // 使用済みにリセット
                    isReadyToNavigate    = true
                }

            } catch {
                locationPrefetchTask = nil
                errorMessage = "処理中にエラーが発生しました: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }

    // AVCapturePhotoOutput で1枚撮影して UIImage を返す（async/await）
    private func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraOCRViewModel: AVCapturePhotoCaptureDelegate {

    // 撮影が完了したときに OS から呼ばれる
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

// MARK: - エラー定義
enum CameraError: LocalizedError {
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .invalidImageData: return "画像データの取得に失敗しました"
        }
    }
}
