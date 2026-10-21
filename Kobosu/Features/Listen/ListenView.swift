//
//  ListenView.swift
//  Kobosu
//
//  「きく」タブ。タイムラインはタスク 6 で作る。
//

import SwiftUI

struct ListenView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Color.clear
            }
            .background(Palette.paper)
            .navigationTitle(Text("きく"))
        }
    }
}

#Preview {
    ListenView()
}
