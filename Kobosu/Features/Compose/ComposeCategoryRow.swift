//
//  ComposeCategoryRow.swift
//  Kobosu
//
//  投稿画面のカテゴリの行（デザイン案 6 枚目）。✦・カテゴリのタグ（紫の線の角丸）・選ばれ方の文言・右端の「変更」。
//  行全体が 1 つのボタンで、押すとカテゴリを選ぶシート（CategorySheet）を開く。VoiceOver では 1 つの要素として読む。
//  文字が大きいときは、選ばれ方の文言を 2 行目に下げ、それでも収まらなければ「変更」も下げてタグを折り返す。
//

import SwiftUI

extension CategorySource {
    /// 行に出す選ばれ方の文言。前回のカテゴリのときは「自動で選びました」と出さない（Discussion #76 の Q3）
    var statusText: LocalizedStringResource {
        switch self {
        case .estimated:
            "自動で選びました"
        case .previous:
            "前回と同じ"
        case .chosen:
            "選びました"
        case .uncategorized:
            "なしでも投稿できます"
        }
    }
}

struct ComposeCategoryRow: View {
    let category: PostCategory
    let source: CategorySource
    let onChange: () -> Void

    @ScaledMetric(relativeTo: .callout) private var tagHeight: CGFloat = 28

    private static let cornerRadius: CGFloat = 22

    var body: some View {
        Button(action: onChange) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    sparkle
                    tag
                    status
                    Spacer(minLength: 8)
                    changeLabel
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        sparkle
                        tag
                        Spacer(minLength: 8)
                        changeLabel
                    }
                    wrappingStatus
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        sparkle
                        wrappingTag
                    }
                    wrappingStatus
                    changeLabel
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(Palette.card)
                    .stroke(Palette.line)
            }
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("カテゴリを変更します"))
        // 音声コントロールで、画面に出ている「変更」と言っても押せるように
        .accessibilityInputLabels([Text("変更"), Text("カテゴリ")])
        .accessibilityIdentifier("compose.category.change")
    }

    private var sparkle: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .accessibilityHidden(true)
    }

    private var tag: some View {
        tagLabel
            .lineLimit(1)
            .fixedSize()
    }

    /// とても大きい文字のときのタグ。幅に収まらなければ折り返す
    private var wrappingTag: some View {
        tagLabel
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tagLabel: some View {
        Text(category.title)
            .font(.zenMaruGothic(.bold, size: 13, relativeTo: .callout))
            .foregroundStyle(Palette.accentDeep)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(minHeight: tagHeight)
            .background {
                RoundedRectangle(cornerRadius: tagHeight / 2, style: .continuous)
                    .fill(Palette.card)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
    }

    private var status: some View {
        Text(source.statusText)
            .kobosuMetaLabel()
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 2 行目以降に下げた選ばれ方の文言。幅に合わせて折り返すので、ViewThatFits が形を選ぶときの幅には数えない
    /// （1 行目のタグと「変更」が収まるかだけで 2 つ目の形を選ぶ）
    private var wrappingStatus: some View {
        status
            .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var changeLabel: some View {
        Text("変更")
            .font(.zenMaruGothic(.bold, size: 14, relativeTo: .subheadline))
            .foregroundStyle(Palette.accentDeep)
            .fixedSize()
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 12) {
        ComposeCategoryRow(category: .partner, source: .estimated) {}
        ComposeCategoryRow(category: .money, source: .previous) {}
        ComposeCategoryRow(category: .housework, source: .chosen) {}
        ComposeCategoryRow(category: .uncategorized, source: .uncategorized) {}
    }
    .padding()
    .background(Palette.paper)
}
