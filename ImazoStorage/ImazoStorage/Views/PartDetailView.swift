import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import UIKit

// 詳細画面のモード（screens.md に準拠）
enum PartDetailMode {
    case register  // 登録モード: OCR結果を確認・修正して保存
    case view      // 閲覧モード: ReadOnly（検索結果タップ後）
    case edit      // 編集モード: 既存パーツの修正
}

// パーツ詳細画面（登録 / 閲覧 / 編集の3モードを1画面で兼ねる）
struct PartDetailView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSettings: UserSettingsService
    @StateObject private var locationService = LocationService()
    private let photoService = PhotoService.shared

    let mode: PartDetailMode

    // 登録モード時に渡されるデータ
    var initialText: String = ""
    var ocrRawText: String = ""
    var capturedImage: UIImage? = nil
    var location: CLLocation? = nil

    // 既存パーツの閲覧・編集時に渡される
    var existingPart: Part? = nil

    // MARK: - フォーム入力値（登録・編集モード）
    @State private var partName: String = ""
    @State private var notes: String = ""

    // MARK: - 閲覧モードのタブ選択
    @State private var selectedTab = 0  // 0=情報, 1=地図

    // MARK: - 確認ダイアログ（D-010）
    @State private var showMarkAsUsedAlert = false
    @State private var showReturnToStorageAlert = false
    @State private var showLocationUpdateAlert = false

    // MARK: - 同名重複チェック（D-002）
    @State private var showDuplicateAlert = false
    @State private var pendingDuplicatePart: Part? = nil

    // MARK: - UI 状態
    @State private var isSaving = false
    @State private var isUpdatingLocation = false
    @State private var showSaveSuccess = false
    @State private var toastMessage = "登録しました"
    @State private var showDiscardAlert = false      // D-016
    @State private var showDeleteAlert = false       // D-024 論理削除
    @State private var showLocationErrorAlert = false

    // MARK: - 写真（閲覧モード用）
    @State private var photo1Image: UIImage? = nil
    @State private var photo2Image: UIImage? = nil
    @State private var fullscreenPhoto: UIImage? = nil      // タップ拡大用
    @State private var isShowingPhoto1Camera = false        // 1枚目撮影シート（閲覧モード）
    @State private var isShowingPhoto2Camera = false        // 2枚目撮影シート（閲覧モード）

    // MARK: - 写真（登録モード用）
    @State private var registerPhoto2Image: UIImage? = nil  // 登録前に撮った2枚目
    @State private var isShowingRegisterPhoto2Camera = false

    var isEditable: Bool { mode == .register || mode == .edit }

    // MARK: - 初期化
    init(mode: PartDetailMode,
         initialText: String = "",
         ocrRawText: String = "",
         capturedImage: UIImage? = nil,
         location: CLLocation? = nil,
         existingPart: Part? = nil) {
        self.mode = mode
        self.initialText = initialText
        self.ocrRawText = ocrRawText
        self.capturedImage = capturedImage
        self.location = location
        self.existingPart = existingPart

        let name = (mode == .register) ? initialText : (existingPart?.name ?? "")
        let note = existingPart?.notes ?? ""
        _partName = State(initialValue: name)
        _notes    = State(initialValue: note)
    }

    // MARK: - body
    var body: some View {
        Group {
            if isEditable {
                editableBody
            } else {
                viewModeBody
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        // 閲覧モード: 編集ボタンを右上に（保管中のみ表示）
        .toolbar {
            if mode == .view, let part = existingPart, part.status == .inStorage {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PartDetailView(mode: .edit, existingPart: part)
                    } label: {
                        Text("編集")
                    }
                }
            }
            if isEditable {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { showDiscardAlert = true }
                }
            }
        }
        // 確認ダイアログ群（D-010）
        .alert("使用済みにしますか？", isPresented: $showMarkAsUsedAlert) {
            Button("使用済みにする", role: .destructive) { markAsUsed() }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("置場に戻しますか？", isPresented: $showReturnToStorageAlert) {
            Button("置場に戻す") { returnToStorage() }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("位置情報を更新しますか？", isPresented: $showLocationUpdateAlert) {
            Button("更新する") { Task { await updateLocation() } }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この端末の現在地が所在地になりますがよろしいですか？")
        }
        // 変更破棄の確認ダイアログ（D-016）
        .alert("変更を破棄しますか？", isPresented: $showDiscardAlert) {
            Button("破棄する", role: .destructive) { dismiss() }
            Button("キャンセル", role: .cancel) {}
        }
        // 論理削除の確認ダイアログ（D-024）
        .alert("このパーツを削除しますか？", isPresented: $showDeleteAlert) {
            Button("削除する", role: .destructive) { softDelete() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除後はデータを復元できません。")
        }
        // 位置情報取得失敗アラート
        .alert("位置情報を取得できませんでした", isPresented: $showLocationErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("位置情報の使用を許可しているか確認してください。")
        }
        // 同名重複の確認ダイアログ（D-002）
        .alert("同名のパーツが存在します", isPresented: $showDuplicateAlert) {
            Button("上書き更新") {
                if let dup = pendingDuplicatePart, let loc = location {
                    overwritePart(dup, name: partName.trimmingCharacters(in: .whitespaces), loc: loc)
                }
            }
            Button("別名で保存") {
                // アラートを閉じてフォームに戻る。ユーザーが名前を修正して再保存する
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("「\(partName)」は既に登録されています。\n既存のパーツを上書きしますか？")
        }
        // 完了トースト（D-014）
        .overlay(alignment: .bottom) {
            if showSaveSuccess {
                Text(toastMessage)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.green, in: Capsule())
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSaveSuccess)
        // 閲覧・編集モード時に既存パーツの写真をロード
        .task(id: existingPart?.id) {
            photo1Image = existingPart?.photo1Path.flatMap { PhotoService.shared.load(fileName: $0) }
            photo2Image = existingPart?.photo2Path.flatMap { PhotoService.shared.load(fileName: $0) }
        }
        // 1枚目写真の撮影シート（閲覧モード）
        .sheet(isPresented: $isShowingPhoto1Camera) {
            NavigationStack {
                SimpleCamera { capturedImg in
                    savePhoto1(capturedImg)
                    isShowingPhoto1Camera = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { isShowingPhoto1Camera = false }
                    }
                }
                .navigationTitle("1枚目を撮影")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        // 登録モードの2枚目撮影シート
        .sheet(isPresented: $isShowingRegisterPhoto2Camera) {
            NavigationStack {
                SimpleCamera { img in
                    registerPhoto2Image = img
                    isShowingRegisterPhoto2Camera = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { isShowingRegisterPhoto2Camera = false }
                    }
                }
                .navigationTitle("2枚目を撮影")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        // 2枚目写真の撮影シート（閲覧モード）
        .sheet(isPresented: $isShowingPhoto2Camera) {
            NavigationStack {
                SimpleCamera { capturedImg in
                    savePhoto2(capturedImg)
                    isShowingPhoto2Camera = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { isShowingPhoto2Camera = false }
                    }
                }
                .navigationTitle("2枚目を撮影")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        // 写真タップ時のフルスクリーン表示
        .sheet(item: Binding(
            get: { fullscreenPhoto.map { IdentifiableImage(image: $0) } },
            set: { fullscreenPhoto = $0?.image }
        )) { item in
            PhotoFullscreenView(image: item.image)
        }
    }

    // MARK: - 閲覧モードのレイアウト

    private var viewModeBody: some View {
        VStack(spacing: 0) {
            // タブ切替（情報 / 地図）
            Picker("", selection: $selectedTab) {
                Text("情報").tag(0)
                Text("地図").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if selectedTab == 0 {
                infoTabContent
            } else {
                mapTabContent
            }

            // アクションボタン（ステータスに応じて出し分け D-012）
            if let part = existingPart {
                actionButtons(for: part)
            }
        }
        .navigationBarBackButtonHidden(false)
    }

    // 情報タブ
    private var infoTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                guard let part = existingPart else { return AnyView(EmptyView()) }
                return AnyView(
                    VStack(alignment: .leading, spacing: 20) {
                        // パーツ名
                        infoRow(label: "パーツ名", icon: "tag") {
                            Text(part.name).font(.title3.bold())
                        }

                        // ステータス
                        infoRow(label: "ステータス", icon: "circle.fill") {
                            Text(part.status.displayName)
                                .font(.body.bold())
                                .foregroundStyle(part.status == .inStorage ? .green : .secondary)
                        }

                        // 備考
                        infoRow(label: "備考", icon: "note.text") {
                            Text(part.notes ?? "なし")
                                .foregroundStyle(part.notes == nil ? .secondary : .primary)
                        }

                        // スキャンテキスト（OCR生テキスト or QRコード値）
                        if let ocr = part.ocrRawText, !ocr.isEmpty {
                            infoRow(label: "スキャンテキスト", icon: "text.viewfinder") {
                                Text(ocr)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        // 登録日時
                        infoRow(label: "登録日時", icon: "calendar") {
                            Text(part.createdAt.formatted(date: .long, time: .shortened))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }

                        // 使用日時（使用済みの場合のみ）
                        if let usedAt = part.usedAt {
                            infoRow(label: "使用日時", icon: "checkmark.circle") {
                                Text(usedAt.formatted(date: .long, time: .shortened))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }

                        // 位置精度（50m超で精度低め警告）
                        if let accuracy = part.locationAccuracy, accuracy > 0 {
                            infoRow(label: "GPS精度", icon: "location") {
                                HStack(spacing: 6) {
                                    Text(String(format: "±%.0fm", accuracy))
                                        .font(.subheadline)
                                        .foregroundStyle(accuracy > 50 ? .orange : .secondary)
                                    if accuracy > 50 {
                                        Label("精度低め", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption.bold())
                                            .foregroundStyle(.orange)
                                            .labelStyle(.titleAndIcon)
                                    }
                                }
                            }
                        }

                        // 写真（D-017: 最大2枚）
                        if photo1Image != nil || photo2Image != nil || part.status == .inStorage {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Label("写真", systemImage: "photo")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if photo1Image != nil || photo2Image != nil {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            if let img = photo1Image {
                                                photoThumbnail(img)
                                            }
                                            if let img = photo2Image {
                                                photoThumbnail(img)
                                            }
                                        }
                                    }
                                }

                                // 1枚目・2枚目の変更ボタン（保管中のみ）
                                if part.status == .inStorage {
                                    HStack(spacing: 12) {
                                        Button {
                                            isShowingPhoto1Camera = true
                                        } label: {
                                            Label("1枚目を変更", systemImage: "camera")
                                                .font(.subheadline)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 44)
                                        }
                                        .buttonStyle(.bordered)

                                        Button {
                                            isShowingPhoto2Camera = true
                                        } label: {
                                            Label(
                                                photo2Image == nil ? "2枚目を追加" : "2枚目を変更",
                                                systemImage: "camera"
                                            )
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                )
            }
        }
    }

    // 地図タブ
    private var mapTabContent: some View {
        Group {
            if let part = existingPart {
                let coordinate = CLLocationCoordinate2D(latitude: part.latitude, longitude: part.longitude)
                Map {
                    Marker(part.name, coordinate: coordinate)
                }
                .mapStyle(.standard)
            } else {
                Text("位置情報がありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // 写真サムネイルのヘルパー（タップでフルスクリーン）
    private func photoThumbnail(_ img: UIImage) -> some View {
        Image(uiImage: img)
            .resizable()
            .scaledToFill()
            .frame(width: 180, height: 135)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { fullscreenPhoto = img }
    }

    // ラベル付き情報行のヘルパー
    private func infoRow<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    // アクションボタン（ステータスで出し分け D-012）
    @ViewBuilder
    private func actionButtons(for part: Part) -> some View {
        VStack(spacing: 12) {
            Divider()

            if part.status == .inStorage {
                // 保管中: 使用済みにする / 位置情報を更新する
                Button {
                    showMarkAsUsedAlert = true
                } label: {
                    Text("使用済みにする")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showLocationUpdateAlert = true
                } label: {
                    Group {
                        if isUpdatingLocation {
                            ProgressView()
                        } else {
                            Text("位置情報を更新する")
                                .font(.body.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .disabled(isUpdatingLocation)

                // 論理削除（D-024）
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Text("削除する")
                        .font(.body)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }

            } else {
                // 使用済み: 置場に戻す のみ
                Button {
                    showReturnToStorageAlert = true
                } label: {
                    Text("置場に戻す")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - 登録・編集モードのレイアウト

    private var editableBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // OCR元画像（登録モードのみ）
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                }

                // パーツ名
                VStack(alignment: .leading, spacing: 6) {
                    Label("パーツ名", systemImage: "tag")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("パーツ名を入力", text: $partName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)

                // 備考
                VStack(alignment: .leading, spacing: 6) {
                    Label("備考（最大500文字）", systemImage: "note.text")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                        .onChange(of: notes) {
                            if notes.count > 500 { notes = String(notes.prefix(500)) }
                        }
                }
                .padding(.horizontal)

                // 2枚目写真（登録モードのみ）
                if mode == .register {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("2枚目の写真（任意）", systemImage: "photo")
                            .font(.caption).foregroundStyle(.secondary)

                        if let img = registerPhoto2Image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 140)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            isShowingRegisterPhoto2Camera = true
                        } label: {
                            Label(
                                registerPhoto2Image == nil ? "2枚目を撮影" : "撮り直す",
                                systemImage: "camera"
                            )
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }

                // 位置情報（表示のみ）
                VStack(alignment: .leading, spacing: 6) {
                    // ラベル行: 「取得位置」の横に精度を並べる
                    HStack(spacing: 8) {
                        Label("取得位置", systemImage: "location")
                            .font(.caption).foregroundStyle(.secondary)
                        if let acc = location?.horizontalAccuracy, acc > 0 {
                            Text(String(format: "±%.0fm以内", acc))
                                .font(.caption)
                                .foregroundStyle(acc > 50 ? .orange : .secondary)
                            if acc > 50 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    let loc = location ?? existingPart.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
                    if let l = loc {
                        Text(String(format: "緯度 %.5f  経度 %.5f", l.coordinate.latitude, l.coordinate.longitude))
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Label("位置情報を取得できませんでした", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)

                // 保存ボタン
                Button { save() } label: {
                    Group {
                        if isSaving { ProgressView() }
                        else { Text(mode == .register ? "登録する" : "保存する").font(.title3.bold()) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .disabled(partName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical)
        }
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - ナビゲーションタイトル
    private var navigationTitle: String {
        switch mode {
        case .register: return "パーツ登録"
        case .view:     return "パーツ詳細"
        case .edit:     return "パーツ編集"
        }
    }

    // MARK: - アクション処理

    // 新規保存（登録）または更新（編集）
    private func save() {
        let name = partName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSaving = true

        if mode == .register {
            guard let loc = location else { isSaving = false; return }

            // D-002: 同名パーツが既に存在するか確認
            if let duplicate = fetchPartByName(name) {
                pendingDuplicatePart = duplicate
                isSaving = false
                showDuplicateAlert = true
                return
            }

            performRegister(name: name, loc: loc)

        } else if mode == .edit, let part = existingPart {
            part.name      = name
            part.notes     = notes.isEmpty ? nil : notes
            part.updatedAt = Date()
            part.updatedBy = userSettings.userName
            addEvent(.edited, to: part, deviceId: userSettings.deviceId)
            toastMessage = "保存しました"
            isSaving = false
            withAnimation { showSaveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        }
    }

    // 新規パーツを登録する（重複なし確認済みの場合に呼ぶ）
    private func performRegister(name: String, loc: CLLocation) {
        // D-023: OCR元画像を1枚目の写真として保存（D-022: JPEG 80%, 長辺1600px）
        let photo1FileName = capturedImage.flatMap { try? photoService.save(image: $0) }
        // 登録前に撮影した2枚目を保存
        let photo2FileName = registerPhoto2Image.flatMap { try? photoService.save(image: $0) }

        let part = Part(
            name: name,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            locationAccuracy: loc.horizontalAccuracy,
            notes: notes.isEmpty ? nil : notes,
            ocrRawText: ocrRawText.isEmpty ? nil : ocrRawText,
            photo1Path: photo1FileName,
            photo2Path: photo2FileName,
            createdBy: userSettings.userName,
            updatedBy: userSettings.userName
        )
        modelContext.insert(part)
        addEvent(.registered, to: part, deviceId: userSettings.deviceId)

        isSaving = false
        toastMessage = "登録しました"
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }

    // D-002: 同名パーツを SwiftData から検索する（論理削除済みは除外）
    private func fetchPartByName(_ name: String) -> Part? {
        let descriptor = FetchDescriptor<Part>(
            predicate: #Predicate { $0.name == name && !$0.isDeleted }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    // D-002: 既存パーツを上書き更新する
    private func overwritePart(_ part: Part, name: String, loc: CLLocation) {
        if let fileName = capturedImage.flatMap({ try? photoService.save(image: $0) }) {
            part.photo1Path = fileName
        }
        part.name             = name
        part.latitude         = loc.coordinate.latitude
        part.longitude        = loc.coordinate.longitude
        part.locationAccuracy = loc.horizontalAccuracy
        part.notes            = notes.isEmpty ? nil : notes
        part.updatedAt        = Date()
        part.updatedBy        = userSettings.userName
        addEvent(.edited, to: part, deviceId: userSettings.deviceId)

        toastMessage = "上書き更新しました"
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }

    // 使用済みにする
    private func markAsUsed() {
        guard let part = existingPart else { return }
        let deviceId = userSettings.deviceId
        part.status    = .used
        part.usedAt    = Date()
        part.updatedAt = Date()
        part.updatedBy = userSettings.userName
        addEvent(.markedAsUsed, to: part, deviceId: deviceId)
        toastMessage = "使用済みにしました"
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }

    // 置場に戻す（位置情報は変えない D-013）
    private func returnToStorage() {
        guard let part = existingPart else { return }
        let deviceId = userSettings.deviceId
        part.status    = .inStorage
        part.usedAt    = nil
        part.updatedAt = Date()
        part.updatedBy = userSettings.userName
        addEvent(.returnedToStorage, to: part, deviceId: deviceId)
        toastMessage = "置場に戻しました"
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }

    // 位置情報を更新する
    private func updateLocation() async {
        guard let part = existingPart else { return }
        isUpdatingLocation = true
        let deviceId = userSettings.deviceId

        do {
            let loc = try await locationService.currentLocation()
            let changesJSON = makeLocationChangesJSON(
                oldLat: part.latitude, oldLon: part.longitude,
                newLat: loc.coordinate.latitude, newLon: loc.coordinate.longitude
            )
            part.latitude         = loc.coordinate.latitude
            part.longitude        = loc.coordinate.longitude
            part.locationAccuracy = loc.horizontalAccuracy
            part.updatedAt        = Date()
            part.updatedBy        = deviceId
            addEvent(.locationUpdated, to: part, deviceId: deviceId, changesJSON: changesJSON)
            toastMessage = "位置情報を更新しました"
            withAnimation { showSaveSuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSaveSuccess = false }
        } catch {
            showLocationErrorAlert = true
        }
        isUpdatingLocation = false
    }

    // 1枚目写真を差し替える
    private func savePhoto1(_ image: UIImage) {
        guard let part = existingPart else { return }

        // 既存の1枚目があれば削除してから上書き
        if let oldPath = part.photo1Path {
            PhotoService.shared.delete(fileName: oldPath)
        }

        guard let fileName = try? PhotoService.shared.save(image: image) else { return }
        part.photo1Path = fileName
        part.updatedAt  = Date()
        part.updatedBy  = userSettings.userName
        addEvent(.photoReplaced, to: part, deviceId: userSettings.deviceId)

        photo1Image = image
        toastMessage = "1枚目を更新しました"
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSaveSuccess = false }
    }

    // 2枚目写真を保存する（D-017）
    private func savePhoto2(_ image: UIImage) {
        guard let part = existingPart else { return }
        let isReplacing = part.photo2Path != nil

        // 既存の2枚目があれば削除してから上書き
        if let oldPath = part.photo2Path {
            PhotoService.shared.delete(fileName: oldPath)
        }

        guard let fileName = try? PhotoService.shared.save(image: image) else { return }
        part.photo2Path = fileName
        part.updatedAt  = Date()
        part.updatedBy  = userSettings.userName
        addEvent(isReplacing ? .photoReplaced : .photoAdded, to: part, deviceId: userSettings.deviceId)

        photo2Image = image
        toastMessage = isReplacing ? "2枚目を更新しました" : "2枚目を追加しました"
        withAnimation { showSaveSuccess = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showSaveSuccess = false }
    }

    // 論理削除（D-024: 物理削除しない）
    private func softDelete() {
        guard let part = existingPart else { return }
        let deviceId = userSettings.deviceId
        part.isDeleted = true
        part.updatedAt = Date()
        part.updatedBy = userSettings.userName
        addEvent(.softDeleted, to: part, deviceId: deviceId)
        dismiss()
    }

    // PartEvent を追加するヘルパー
    private func addEvent(_ type: PartEventType, to part: Part, deviceId: String, changesJSON: String? = nil) {
        let event = PartEvent(
            partId: part.id,
            partNameSnapshot: part.name,
            eventType: type,
            changesJSON: changesJSON,
            actorId: deviceId,
            actorName: userSettings.userName,
            deviceId: deviceId
        )
        modelContext.insert(event)
    }

    // 位置変更の changesJSON を生成
    private func makeLocationChangesJSON(oldLat: Double, oldLon: Double, newLat: Double, newLon: Double) -> String? {
        let changes: [[String: String]] = [
            ["field": "latitude",  "before": String(oldLat), "after": String(newLat)],
            ["field": "longitude", "before": String(oldLon), "after": String(newLon)]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: changes),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return json
    }
}

// MARK: - シンプルカメラ（2枚目写真撮影用）

// UIImagePickerController を SwiftUI から使うためのラッパー
private struct SimpleCamera: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                onCapture(img)
            }
        }
    }
}

// MARK: - 写真フルスクリーン表示

// UIImage を Identifiable にするためのラッパー（.sheet(item:) に必要）
private struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// 写真をピンチズームで見られるフルスクリーンビュー
private struct PhotoFullscreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .background(.black)
            .navigationTitle("写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
