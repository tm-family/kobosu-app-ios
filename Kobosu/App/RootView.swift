//
//  RootView.swift
//  Kobosu
//
//  起動して最初に出す画面を選ぶ。やさしさの約束に同意していなければ初回の画面、同意していればタブ。
//  同意した約束の版は端末内（UserDefaults）にだけ保存する。撮影モードでは初回の画面を飛ばす。
//

import SwiftUI

struct RootView: View {
    let dependencies: AppDependencies

    @AppStorage(OnboardingStatus.agreedVersionKey) private var agreedPromiseVersion = 0

    var body: some View {
        if OnboardingStatus.needsOnboarding(agreedVersion: agreedPromiseVersion, isScreenshotDemo: ScreenshotDemo.isEnabled) {
            OnboardingView {
                agreedPromiseVersion = PromiseRule.currentVersion
            }
        } else {
            MainTabView(dependencies: dependencies)
        }
    }
}

#Preview {
    RootView(dependencies: .demo())
}
