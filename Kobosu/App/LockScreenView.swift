//
//  LockScreenView.swift
//  Kobosu
//
//  ロック解除の画面（デザイン案 08）。2 回目以降の起動とアプリ切り替えのたびに出し、中身は一切見せない。
//  Face ID で開けないときは、システムの確認の画面からパスコードに切り替えられる。
//

import SwiftUI

struct LockScreenView: View {
    let controller: AppLockController

    @ScaledMetric(relativeTo: .largeTitle) private var buttonSize: CGFloat = 72

    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            AppMark(gradient: true)
            Button {
                Task { await controller.unlock(reason: Self.reason) }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: controller.method.systemImage)
                        .font(.system(size: buttonSize * 0.45))
                        .foregroundStyle(Palette.accent)
                        .frame(width: buttonSize, height: buttonSize)
                        .background(Palette.lavender, in: Circle())
                    Text(openTitle)
                        .font(.kobosuCaption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .frame(minWidth: KobosuButtonStyle.minimumTapSize, minHeight: KobosuButtonStyle.minimumTapSize)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(controller.isAuthenticating)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(openTitle))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("lock.unlock")
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .floralBackground()
    }

    /// システムの確認の画面に出す理由
    static var reason: String {
        String(localized: "こぼすを開くために、本人か確かめます")
    }

    private var openTitle: LocalizedStringResource {
        switch controller.method {
        case .faceID:
            "Face ID で開く"
        case .touchID:
            "Touch ID で開く"
        case .opticID:
            "Optic ID で開く"
        case .passcode:
            "パスコードで開く"
        }
    }
}

/// アプリスイッチャーやコントロールセンターを開いたときに、中身を覆う
struct PrivacyCoverView: View {
    var body: some View {
        AppMark()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .floralBackground()
            .accessibilityHidden(true)
    }
}

#Preview("ロック解除") {
    LockScreenView(
        controller: AppLockController(
            authenticator: StubAppLockAuthenticator(),
            settings: AppLockSettings(defaults: .init()),
            isLockAvailable: { true }
        )
    )
}

#Preview("中身を覆う") {
    PrivacyCoverView()
}
