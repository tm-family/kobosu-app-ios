//
//  Kobosu.swift
//  Kobosu
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftUI

@main
struct Kobosu: App {
    @State private var dependencies: AppDependencies

    init() {
        OnboardingStatus.applyLaunchArguments(ProcessInfo.processInfo.arguments, to: .standard)
        NavigationBarAppearance.apply()
        // GoogleService-Info.plist があれば Firebase を設定し、Firestore の実装で動かす（無ければローカルの実装）。
        // 撮影モードではデモデータで開く
        let usesFirebase = FirebaseSetup.configureIfAvailable(isScreenshotDemo: ScreenshotDemo.isEnabled)
        let dependencies: AppDependencies
        if ScreenshotDemo.isEnabled {
            dependencies = .demo()
        } else if usesFirebase {
            dependencies = .firebase()
        } else {
            dependencies = .local()
        }
        _dependencies = State(initialValue: dependencies)
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    /// 撮影モード（ScreenshotDemo）のときは、撮る画面を開く
    @ViewBuilder private var rootView: some View {
        switch ScreenshotDemo.scene {
        case .home, nil:
            RootView(dependencies: dependencies)
        case .empathy:
            MainTabView(dependencies: dependencies, empathyPostID: ScreenshotDemo.empathyPostID)
        case .compose:
            MainTabView(dependencies: dependencies, opensComposer: true)
        case .note:
            MainTabView(dependencies: dependencies, initialTab: .note)
        case .welcome:
            OnboardingView(authenticator: dependencies.appLock, lockSettings: dependencies.lockSettings) {}
        }
    }
}
