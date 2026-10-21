//
//  PostTextArea.swift
//  Kobosu
//
//  投稿テキストエリア（COMPONENTS 3/3）。角丸 22pt・本文 15pt・行間 1.6・カーソルは紫。
//  入力前は「いま、どんな気持ち？」と出し、右下に「23 / 400」の形で文字数を出す。上限を超えた分は切り落とす。
//

import SwiftUI

struct PostTextArea: View {
    @Binding var text: String
    /// 上限の文字数
    let limit: Int

    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 160

    /// 本文 15pt に行間 1.6 を付けるための、行と行のあいだの余白
    private static let lineSpacing: CGFloat = 15 * 0.6

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $text)
                .font(.kobosuBody)
                .foregroundStyle(Palette.ink)
                .lineSpacing(Self.lineSpacing)
                .tint(Palette.accent)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("いま、どんな気持ち？")
                            .font(.kobosuBody)
                            .foregroundStyle(Palette.inkSecondary)
                            // TextEditor の文字の始まりにそろえる
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityLabel(Text("いま、どんな気持ち？"))
            Text(verbatim: "\(text.count) / \(limit)")
                .roundedFont(size: 12, weight: .medium, relativeTo: .caption)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityLabel(Text("\(limit) 文字中 \(text.count) 文字"))
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: text) { _, newValue in
            let clamped = TextLimit.clamped(newValue, to: limit)
            if clamped != newValue {
                text = clamped
            }
        }
    }
}

#Preview("投稿テキストエリア") {
    @Previewable @State var text = "「手伝おうか」って言われるたびにモヤっとする。"
    @Previewable @State var empty = ""
    VStack(spacing: 16) {
        PostTextArea(text: $text, limit: 400)
        PostTextArea(text: $empty, limit: 400)
    }
    .padding()
    .background(Palette.paper)
}
