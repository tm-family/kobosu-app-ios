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

    @AppStorage("onboarding.agreedPromiseVersion") private var agreedPromiseVersion = 0

    var body: some View {
        if ScreenshotDemo.isEnabled || agreedPromiseVersion >= PromiseRule.currentVersion {
            MainTabView(dependencies: dependencies)
        } else {
            OnboardingView {
                agreedPromiseVersion = PromiseRule.currentVersion
            }
        }
    }
}

#Preview {
    RootView(dependencies: .demo())
}
