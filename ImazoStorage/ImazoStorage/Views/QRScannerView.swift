import SwiftUI
import AVFoundation

// QRコードスキャン画面
// カメラのライブプレビューを表示し、QRコードを自動検出したら
// 写真撮影・GPS取得を行ってパーツ登録画面（PartDetailView）へ遷移する
struct QRScannerView: View {

    @StateObject private var viewModel = QRScannerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // ── カメラライブプレビュー（全画面）────────────────────
            // CameraPreview は CameraOCRView.swift で定義済みのコンポーネントを流用
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            // ── スキャンガイドオーバーレイ ───────────────────────
            if !viewModel.isProcessing {
                scanGuideOverlay
            }

            // ── QRコード検出後の処理中インジケータ ──────────────
            if viewModel.isProcessing {
                processingOverlay
            }

            // ── エラーメッセージ ─────────────────────────────────
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
        }
        .navigationTitle("QRコードスキャン")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        // QRコード検出・写真撮影・GPS取得が全て完了したらパーツ登録画面へ
        .navigationDestination(isPresented: $viewModel.isReadyToNavigate) {
            PartDetailView(
                mode: .register,
                initialText: viewModel.qrCodeText,
                ocrRawText: viewModel.qrCodeText,   // QRコード値をスキャンテキストとして保存
                capturedImage: viewModel.capturedImage,
                location: viewModel.capturedLocation
            )
        }
        .onAppear { viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
    }

    // MARK: - スキャンガイドオーバーレイ

    // ターゲット枠の外側を暗くして、枠内にQRコードを合わせるよう誘導する
    private var scanGuideOverlay: some View {
        ZStack {
            // 枠外を暗くする（枠内だけ透明に抜く）
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 240, height: 240)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

            // ターゲット枠の白い枠線
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white, lineWidth: 3)
                .frame(width: 240, height: 240)

            // 案内テキスト（枠の下に表示）
            VStack {
                Spacer()
                Text("QRコードを枠内に合わせてください")
                    .foregroundStyle(.white)
                    .font(.subheadline)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .padding(.bottom, 56)
            }
        }
    }

    // MARK: - 処理中オーバーレイ

    // QRコード検出後、写真撮影とGPS取得が完了するまで表示する
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                Text("QRコードを読み取りました\nGPS取得中...")
                    .foregroundStyle(.white)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
