//
//  PostTextArea.swift
//  Kobosu
//
//  投稿テキストエリア（COMPONENTS 3/3）。角丸 22pt・本文 15pt・行間 1.6・カーソルは紫。
//  入力前は「いま、どんな気持ち？」と出し、右下に「23 / 400」の形で文字数を出す。
//  上限を超えても入力は切り落とさず（変換中の文字や途中への貼り付けを消さないため）、文字数を注意の色にする。
//  上限を超えたときに投稿させないのは、使う側（投稿画面）で行う。
//

import SwiftUI

struct PostTextArea: View {
    @Binding var text: String
    /// 上限の文字数
    let limit: Int
    /// 表示する文字数。nil なら text の文字数
    var count: Int?

    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 160
    /// 本文 15pt の行の高さを 1.6 倍にするための、行と行のあいだの余白。
    /// Zen Maru Gothic はもともと行の高さが約 1.45 倍あるので、差の 0.15 倍（約 2.3pt）だけ足す
    @ScaledMetric(relativeTo: .body) private var lineSpacing: CGFloat = 15 * 0.15

    private static let cornerRadius: CGFloat = 22

    private var displayedCount: Int {
        count ?? text.count
    }

    private var isOverLimit: Bool {
        displayedCount > limit
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $text)
                .font(.kobosuBody)
                .foregroundStyle(Palette.ink)
                .lineSpacing(lineSpacing)
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
            Text(verbatim: "\(displayedCount) / \(limit)")
                .roundedFont(size: 12, weight: isOverLimit ? .bold : .medium, relativeTo: .caption)
                .foregroundStyle(isOverLimit ? Palette.caution : Palette.inkSecondary)
                .accessibilityLabel(
                    isOverLimit
                        ? Text("\(limit) 文字をこえています。いまは \(displayedCount) 文字")
                        : Text("\(limit) 文字中 \(displayedCount) 文字")
                )
        }
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(isOverLimit ? Palette.caution : Palette.line, lineWidth: 1)
        }
    }
}

#Preview("投稿テキストエリア") {
    @Previewable @State var text = "「手伝おうか」って言われるたびにモヤっとする。"
    @Previewable @State var empty = ""
    @Previewable @State var long = String(repeating: "モヤっとする。", count: 60)
    VStack(spacing: 16) {
        PostTextArea(text: $text, limit: Post.maxBodyLength)
        PostTextArea(text: $empty, limit: Post.maxBodyLength)
        PostTextArea(text: $long, limit: Post.maxBodyLength)
    }
    .padding()
    .background(Palette.paper)
}
