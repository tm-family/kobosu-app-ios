//
//  KobosuCard.swift
//  Kobosu
//
//  カード（角丸 22pt・カードの色の面）。投稿カードや設定のまとまりに使う。
//

import SwiftUI

private struct KobosuCardModifier: ViewModifier {
    /// カードの角丸
    static let cornerRadius: CGFloat = 22

    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}

extension View {
    /// カードの面に載せる。幅いっぱいに広げ、中身は左寄せにする
    func kobosuCard(padding: CGFloat = 16) -> some View {
        modifier(KobosuCardModifier(padding: padding))
    }
}

#Preview("カード") {
    VStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "今日も黙って洗い物をした。")
                .font(.kobosuBody)
                .foregroundStyle(Palette.ink)
            Text(verbatim: "残り 22時間")
                .kobosuMetaLabel()
        }
        .kobosuCard()
    }
    .padding()
    .background(Palette.paper)
}
