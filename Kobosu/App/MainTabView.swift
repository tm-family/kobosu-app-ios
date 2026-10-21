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
    @State private var selection: MainTab = .listen
    @State private var isComposing = false

    var body: some View {
        TabView(selection: $selection) {
            ListenView()
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.listen)
            NoteView()
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.note)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KobosuTabBar(selection: $selection) {
                isComposing = true
            }
        }
        .sheet(isPresented: $isComposing) {
            ComposeView()
        }
    }
}

#Preview {
    MainTabView()
}
