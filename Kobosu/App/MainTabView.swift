//
//  MainTabView.swift
//  Kobosu
//
//  「きく」「ノート」の 2 つのタブと、タブバー中央の「こぼす」ボタンから開く投稿のモーダル。
//  タブバーは標準のものを隠して KobosuTabBar を出す（中央のボタンをタブバーから浮かせるため）。
//  撮影モードでは、開くタブ・投稿のモーダル・共感のシートを最初から指定して開く。
//

import SwiftUI

enum MainTab: Hashable {
    case listen
    case note
}

struct MainTabView: View {
    let dependencies: AppDependencies
    /// 読み込んだら共感のシートを開く投稿（撮影モード）
    private let empathyPostID: Post.ID?

    @State private var selection: MainTab
    @State private var isComposing: Bool
    @State private var isShowingSettings = false
    /// 投稿した回数。変わるとタイムラインを読み直す
    @State private var postedCount = 0

    init(
        dependencies: AppDependencies,
        initialTab: MainTab = .listen,
        opensComposer: Bool = false,
        empathyPostID: Post.ID? = nil
    ) {
        self.dependencies = dependencies
        self.empathyPostID = empathyPostID
        _selection = State(initialValue: initialTab)
        _isComposing = State(initialValue: opensComposer)
    }

    var body: some View {
        TabView(selection: $selection) {
            ListenView(
                repository: dependencies.posts,
                reports: dependencies.reports,
                reloadID: postedCount,
                empathyPostID: empathyPostID
            )
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.listen)
            NoteView(repository: dependencies.posts) {
                isShowingSettings = true
            }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.note)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KobosuTabBar(selection: $selection) {
                isComposing = true
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(
                authenticator: dependencies.appLock,
                lockSettings: dependencies.lockSettings,
                eraser: dependencies.makeEraser()
            )
        }
        .sheet(isPresented: $isComposing) {
            ComposeView(repository: dependencies.posts, drafts: dependencies.drafts, lastCategories: dependencies.lastCategories) { _ in
                postedCount += 1
                selection = .listen
            }
        }
    }
}

#Preview {
    MainTabView(dependencies: .demo())
}
