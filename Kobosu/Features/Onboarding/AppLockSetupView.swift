//
//  AppLockSetupView.swift
//  Kobosu
//
//  初回起動の「アプリロック設定」（デザイン案 07）。家族と同じ端末や画面を見られる場面を想定し、初期値はオン。
//  通知を入れない今回は「通知に本文を出さない」の設定は出さない。
//

import SwiftUI

struct AppLockSetupView: View {
    let onFinish: () -> Void

    @State private var model: AppLockSetupViewModel
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 88

    init(authenticator: any AppLockAuthenticating, settings: AppLockSettings, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: AppLockSetupViewModel(authenticator: authenticator, settings: settings))
    }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: model.method?.systemImage ?? "lock")
                        .font(.system(size: iconSize * 0.45, weight: .regular))
                        .foregroundStyle(Palette.accent)
                        .frame(width: iconSize, height: iconSize)
                        .background(Palette.lavender, in: Circle())
                        .accessibilityHidden(true)
                        .padding(.top, 48)
                    Text("家族に見られないように")
                        .font(.kobosuTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("開くときに、ロックをかけられます。あとから設定でも変えられます。")
                        .font(.kobosuBody)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                    lockToggle
                    if model.state == .failed {
                        Text("ロックを確かめられませんでした。もう一度ためすか、あとで設定できます。")
                            .font(.kobosuCaption)
                            .foregroundStyle(Palette.caution)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 4) {
                Button {
                    Task {
                        if await model.confirm(reason: String(localized: "アプリのロックを確かめます")) {
                            onFinish()
                        }
                    }
                } label: {
                    Text("設定して次へ")
                }
                .buttonStyle(.kobosuPrimary)
                .disabled(model.state == .authenticating)
                .accessibilityIdentifier("onboarding.lockNext")
                Button {
                    model.skip()
                    onFinish()
                } label: {
                    Text("あとで設定する")
                }
                .buttonStyle(.kobosuText)
                .disabled(model.state == .authenticating)
                .accessibilityIdentifier("onboarding.lockLater")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.paper)
    }

    @ViewBuilder private var lockToggle: some View {
        if let method = model.method {
            Toggle(isOn: $model.isLockOn) {
                Text(method.title)
                    .font(.kobosuBody)
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.accent)
            .disabled(model.state == .authenticating)
            .accessibilityIdentifier("onboarding.lockToggle")
            .kobosuCard(padding: 16)
        } else {
            Text("この端末にはパスコードが設定されていないため、ロックは使えません。端末の設定でパスコードを決めると使えるようになります。")
                .font(.kobosuCaption)
                .foregroundStyle(Palette.inkSecondary)
                .kobosuCard(padding: 16)
        }
    }
}

#Preview {
    AppLockSetupView(authenticator: StubAppLockAuthenticator(), settings: AppLockSettings(defaults: .init()), onFinish: {})
}

#Preview("ロックを使えない端末") {
    AppLockSetupView(
        authenticator: StubAppLockAuthenticator(method: nil),
        settings: AppLockSettings(defaults: .init()),
        onFinish: {}
    )
}
