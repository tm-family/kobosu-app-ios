//
//  SettingsView.swift
//  Kobosu
//
//  設定（デザイン案 13）。プライバシーを先頭に置く。
//  アプリロックの切り替え・すべてのデータを削除・運営への連絡先・利用規約とプライバシーポリシー・ライセンス表記。
//  運営の連絡先と規約の URL は SupportInfo に置く。nil のものは出さない。
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: SettingsViewModel
    @State private var isConfirmingErase = false

    init(authenticator: any AppLockAuthenticating, lockSettings: AppLockSettings, eraser: DataEraser) {
        _model = State(initialValue: SettingsViewModel(authenticator: authenticator, lockSettings: lockSettings, eraser: eraser))
    }

    var body: some View {
        NavigationStack {
            List {
                privacySection
                dataSection
                if SupportInfo.contactURL != nil || SupportInfo.termsURL != nil || SupportInfo.privacyPolicyURL != nil {
                    supportSection
                }
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Palette.paper)
            .font(.kobosuBody)
            .foregroundStyle(Palette.ink)
            .navigationTitle(Text("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                    }
                    .disabled(model.eraseState == .erasing)
                    .accessibilityIdentifier("settings.close")
                }
            }
            .interactiveDismissDisabled(model.eraseState == .erasing)
            .confirmationDialog(
                Text("すべてのデータを削除しますか？"),
                isPresented: $isConfirmingErase,
                titleVisibility: .visible
            ) {
                // 赤（destructive）にしないため、role は付けない
                Button {
                    Task { await model.eraseAll() }
                } label: {
                    Text("すべて削除する")
                }
                Button(role: .cancel) {} label: {
                    Text("キャンセル")
                }
            } message: {
                Text("共有した投稿・送った共感・下書き・設定と、この端末の匿名 ID を消します。もとには戻せません。")
            }
        }
    }

    private var privacySection: some View {
        Section {
            if let method = model.lockMethod {
                Toggle(isOn: lockBinding) {
                    Text(method.title)
                }
                .tint(Palette.accent)
                .disabled(model.isChangingLock)
                .accessibilityIdentifier("settings.lock")
            } else {
                Text("この端末にはパスコードが設定されていないため、ロックは使えません。")
                    .kobosuMetaLabel()
            }
        } header: {
            sectionTitle("プライバシー")
        } footer: {
            Text("オンにすると、開くたびとアプリを切り替えるたびに確かめます。")
                .kobosuMetaLabel()
        }
        .listRowBackground(Palette.card)
    }

    private var lockBinding: Binding<Bool> {
        Binding {
            model.isLockOn
        } set: { isOn in
            Task { await model.setLock(isOn, reason: String(localized: "ロックをかけるために、本人か確かめます")) }
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                isConfirmingErase = true
            } label: {
                HStack {
                    Text("すべてのデータを削除")
                        .foregroundStyle(model.eraseState == .erasing ? Palette.disabledInk : Palette.caution)
                    Spacer()
                    if model.eraseState == .erasing {
                        ProgressView()
                    }
                }
                .frame(minHeight: KobosuButtonStyle.minimumTapSize)
                .contentShape(Rectangle())
            }
            .disabled(model.eraseState == .erasing)
            .accessibilityIdentifier("settings.erase")
            if model.eraseState == .failed {
                Text("削除できませんでした。端末の中のデータは消していません。時間をおいて、もう一度ためせます。")
                    .font(.kobosuCaption)
                    .foregroundStyle(Palette.caution)
            }
        } header: {
            sectionTitle("データ")
        }
        .listRowBackground(Palette.card)
    }

    private var supportSection: some View {
        Section {
            if let url = SupportInfo.contactURL {
                linkRow("運営への連絡", url: url)
            }
            if let url = SupportInfo.termsURL {
                linkRow("利用規約", url: url)
            }
            if let url = SupportInfo.privacyPolicyURL {
                linkRow("プライバシーポリシー", url: url)
            }
        } header: {
            sectionTitle("お問い合わせ")
        }
        .listRowBackground(Palette.card)
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                LicenseView()
            } label: {
                Text("ライセンス")
            }
            .accessibilityIdentifier("settings.license")
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                LabeledContent {
                    Text(verbatim: version)
                        .roundedFont(size: 15, weight: .regular)
                        .foregroundStyle(Palette.inkSecondary)
                } label: {
                    Text("バージョン")
                }
            }
        } header: {
            sectionTitle("このアプリについて")
        }
        .listRowBackground(Palette.card)
    }

    private func linkRow(_ title: LocalizedStringResource, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: KobosuButtonStyle.minimumTapSize)
            .contentShape(Rectangle())
        }
    }

    private func sectionTitle(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.zenMaruGothic(.bold, size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.inkSecondary)
    }
}

#Preview {
    let dependencies = AppDependencies.demo()
    SettingsView(authenticator: dependencies.appLock, lockSettings: dependencies.lockSettings, eraser: dependencies.makeEraser())
}
