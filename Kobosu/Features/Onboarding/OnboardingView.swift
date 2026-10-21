//
//  OnboardingView.swift
//  Kobosu
//
//  初回起動の流れ。ようこそ → やさしさの約束 → アプリロックの設定。
//  アプリロックを決めたら onFinish を呼ぶ（約束に同意したことも、このとき保存する）。
//  途中でアプリを閉じたら、次に開いたときにもう一度はじめから出す。
//

import SwiftUI

struct OnboardingView: View {
    let authenticator: any AppLockAuthenticating
    let lockSettings: AppLockSettings
    let onFinish: () -> Void

    @State private var step = Step.welcome

    private enum Step {
        case welcome
        case promise
        case appLock
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeView {
                    withAnimation {
                        step = .promise
                    }
                }
            case .promise:
                PromiseView {
                    withAnimation {
                        step = .appLock
                    }
                }
                .transition(.move(edge: .trailing))
            case .appLock:
                AppLockSetupView(authenticator: authenticator, settings: lockSettings, onFinish: onFinish)
                    .transition(.move(edge: .trailing))
            }
        }
    }
}

#Preview {
    OnboardingView(authenticator: StubAppLockAuthenticator(), lockSettings: AppLockSettings(defaults: .init())) {}
}
