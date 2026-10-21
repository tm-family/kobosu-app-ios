//
//  NoteView.swift
//  Kobosu
//
//  「ノート」タブ。自分の投稿（共有した）はタスク 12 で作る。
//

import SwiftUI

struct NoteView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Color.clear
            }
            .background(Palette.paper)
            .navigationTitle(Text("ノート"))
        }
    }
}

#Preview {
    NoteView()
}
