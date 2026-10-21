//
//  Kobosu.swift
//  Kobosu
//
//  Created by 村石 拓海 on 2024/05/12.
//

import SwiftUI

@main
struct Kobosu: App {
    /// 撮影モードではデモデータで開く
    @State private var dependencies = ScreenshotDemo.isEnabled ? AppDependencies.demo() : AppDependencies.local()

    init() {
        NavigationBarAppearance.apply()
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
            MainTabView(dependencies: dependencies)
        }
    }
}
