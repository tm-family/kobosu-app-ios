//
//  KobosuLabels.swift
//  Kobosu
//
//  デザイン案（COMPONENTS 2/3）のラベル。
//

import SwiftUI

/// カテゴリタグ（高さ 22pt・12pt Bold・淡い紫の面＋濃い紫の文字）。投稿の分類を示す
struct CategoryTag: View {
    let title: LocalizedStringResource

    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 22

    var body: some View {
        Text(title)
            .font(.zenMaruGothic(.bold, size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.accentDeep)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: height)
            .background(Palette.lavender, in: Capsule())
    }
}

extension View {
    /// 補足ラベル（12pt Medium・補足の文字色）。残り時間や「パートナー · 2時間前」など
    func kobosuMetaLabel() -> some View {
        font(.kobosuCaption)
            .foregroundStyle(Palette.inkSecondary)
    }
}

#Preview("ラベル") {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            CategoryTag(title: "義理の親")
            CategoryTag(title: "子育て")
        }
        Text(verbatim: "残り 22時間")
            .kobosuMetaLabel()
        Text(verbatim: "パートナー · 2時間前")
            .kobosuMetaLabel()
    }
    .padding()
    .background(Palette.paper)
}
