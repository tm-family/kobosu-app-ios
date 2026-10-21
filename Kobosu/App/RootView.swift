//
//  RootView.swift
//  Kobosu
//
//  起動して最初に出す画面を選ぶ。やさしさの約束に同意していなければ初回の画面、同意していればタブ。
//  初回の画面はアプリロックの設定まで進んでから閉じる（約束に同意した版は、アプリロックを決めたときに保存する）。
//  アプリロックがオンなら、2 回目以降の起動とアプリ切り替えのたびにロック解除の画面を出す（撮影モードでは出さない）。
//  前に出ていないとき（アプリスイッチャー・コントロールセンター）は中身を覆い、スナップショットにも本文を映さない。
//  同意した約束の版は端末内（UserDefaults）にだけ保存する。撮影モードでは初回の画面を飛ばす。
//

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    @AppStorage(OnboardingStatus.agreedVersionKey) private var agreedPromiseVersion = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock: AppLockController

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _lock = State(
            initialValue: AppLockController(authenticator: dependencies.appLock, settings: dependencies.lockSettings) {
                // 初回の画面を終えるまで・撮影モードではロックしない
                !ScreenshotDemo.isEnabled
                    && !OnboardingStatus.needsOnboarding(
                        agreedVersion: UserDefaults.standard.integer(forKey: OnboardingStatus.agreedVersionKey),
                        isScreenshotDemo: false
                    )
            }
        )
    }

    var body: some View {
        ZStack {
            if OnboardingStatus.needsOnboarding(agreedVersion: agreedPromiseVersion, isScreenshotDemo: ScreenshotDemo.isEnabled) {
                OnboardingView(authenticator: dependencies.appLock, lockSettings: dependencies.lockSettings) {
                    agreedPromiseVersion = PromiseRule.currentVersion
                }
            } else {
                MainTabView(dependencies: dependencies)
                    // ロック中は、中身を VoiceOver にも読ませない
                    .accessibilityHidden(lock.isLocked)
            }
            if lock.isLocked {
                LockScreenView(controller: lock)
                    .transition(.opacity)
            } else if scenePhase != .active, !ScreenshotDemo.isEnabled {
                PrivacyCoverView()
            }
        }
        .animation(.easeOut(duration: 0.2), value: lock.isLocked)
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                lock.didEnterBackground()
            case .active:
                Task { await lock.didBecomeActive(reason: LockScreenView.reason) }
            default:
                break
            }
        }
    }
}

#Preview {
    RootView(dependencies: .demo())
}
