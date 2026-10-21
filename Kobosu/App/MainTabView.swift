//
//  MainTabView.swift
//  Kobosu
//
//  「きく」「ノート」の 2 つのタブと、タブバー中央の「こぼす」ボタンから開く投稿のモーダル。
//  タブバーは標準のものを隠して KobosuTabBar を出す（中央のボタンをタブバーから浮かせるため）。
//

import SwiftUI

enum MainTab: Hashable {
    case listen
    case note
}

struct MainTabView: View {
    let dependencies: AppDependencies

    @State private var selection: MainTab = .listen
    @State private var isComposing = false
    /// 投稿した回数。変わるとタイムラインを読み直す
    @State private var postedCount = 0

    var body: some View {
        TabView(selection: $selection) {
            ListenView(repository: dependencies.posts, reloadID: postedCount)
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.listen)
            NoteView(repository: dependencies.posts)
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.note)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KobosuTabBar(selection: $selection) {
                isComposing = true
            }
        }
        .sheet(isPresented: $isComposing) {
            ComposeView(repository: dependencies.posts, drafts: dependencies.drafts) { _ in
                postedCount += 1
                selection = .listen
            }
        }
    }
}

#Preview {
    MainTabView(dependencies: .demo())
}
