import SwiftUI
import AVFoundation

// カメラ+OCR画面
// カメラプレビューを表示し、シャッターを押すと OCR + GPS を取得して詳細画面へ遷移する
// onSearchComplete が渡された場合は「検索モード」: OCRテキストをコールバックで返す（GPS不要）
struct CameraOCRView: View {

    var onSearchComplete: ((String) -> Void)? = nil

    @StateObject private var viewModel = CameraOCRViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // ── カメラプレビュー（全画面）────────────────
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            // ── 処理中インジケータ ─────────────────────
            if viewModel.isProcessing {
                Color.black.opacity(0.5).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("読み取り中...")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
            }

            // ── エラーメッセージ ───────────────────────
            if let message = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(message)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 120)
                }
            }

            // ── シャッターボタン ───────────────────────
            if !viewModel.isProcessing {
                VStack {
                    Spacer()
                    // 照準ガイド（パーツの文字に合わせる目安）
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.7), lineWidth: 2)
                        .frame(width: 280, height: 120)

                    Spacer()

                    Button {
                        viewModel.captureAndProcess()
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.5), lineWidth: 4)
                                    .frame(width: 84, height: 84)
                            }
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .navigationTitle("パーツをスキャン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // OCR + GPS が完了したら PartDetailView へ遷移
        .navigationDestination(isPresented: $viewModel.isReadyToNavigate) {
            PartDetailView(
                mode: .register,
                initialText: viewModel.recognizedText,
                ocrRawText: viewModel.ocrRawText,
                capturedImage: viewModel.capturedImage,
                location: viewModel.capturedLocation
            )
        }
        .onAppear {
            // 検索モードのコールバックを ViewModel にセット
            viewModel.searchCompletionHandler = onSearchComplete.map { handler in
                { text in
                    handler(text)
                    dismiss()  // シートとして表示されている場合は閉じる
                }
            }
            viewModel.startSession()
        }
        .onDisappear { viewModel.stopSession() }
    }
}

// MARK: - カメラプレビュー（UIKit の AVCaptureVideoPreviewLayer を SwiftUI で使う）
// SwiftUI には直接カメラプレビューを表示する機能がないため、
// UIViewRepresentable を使って UIKit のビューを埋め込む
struct CameraPreview: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    // AVCaptureVideoPreviewLayer をルートレイヤーとして持つカスタムビュー
    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
