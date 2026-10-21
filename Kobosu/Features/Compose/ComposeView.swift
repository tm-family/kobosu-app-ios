//
//  ComposeView.swift
//  Kobosu
//
//  タブバー中央の「こぼす」ボタンから開く投稿のモーダル。投稿画面の中身はタスク 9 で作る。
//  ナビゲーションバーは左が取り消し・中央がタイトル（COMPONENTS 3/3）。
//

import SwiftUI

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Color.clear
            }
            .background(Palette.paper)
            .navigationTitle(Text("こぼす"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("キャンセル")
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityIdentifier("compose.cancel")
                }
            }
        }
    }
}

#Preview {
    ComposeView()
}
