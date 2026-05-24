import SwiftUI

// 初回起動時にユーザー名を入力させる画面（D-021）
// 名前を入力して「はじめる」を押すまで、メイン画面には進めない
struct UserSetupView: View {

    @EnvironmentObject private var userSettings: UserSettingsService
    @State private var inputName: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── ロゴ ─────────────────────────────────────
            VStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("置場ナビ")
                    .font(.title.bold())

                Text("ようこそ")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // ── 名前入力エリア ────────────────────────────
            VStack(alignment: .leading, spacing: 12) {
                Text("あなたの名前を入力してください")
                    .font(.headline)

                Text("入力した名前は操作の記録（誰が登録・更新したか）に使われます。\n現場で呼ばれる名前や社員番号でも構いません。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("例: 田中一郎", text: $inputName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .autocorrectionDisabled()
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { saveAndStart() }
            }
            .padding(.horizontal, 24)

            Spacer()

            // ── はじめるボタン ────────────────────────────
            Button {
                saveAndStart()
            } label: {
                Text("はじめる")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputName.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            // キーボードを自動で出す
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }

    private func saveAndStart() {
        let name = inputName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        userSettings.userName = name
    }
}

#Preview {
    UserSetupView()
        .environmentObject(UserSettingsService())
}
