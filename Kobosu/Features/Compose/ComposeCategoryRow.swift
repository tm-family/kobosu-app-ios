//
//  ComposeCategoryRow.swift
//  Kobosu
//
//  投稿画面のカテゴリの行（デザイン案 6 枚目）。✦・カテゴリのタグ（紫の線の角丸）・選ばれ方の文言・右端の「変更」。
//  行全体が 1 つのボタンで、押すとカテゴリを選ぶシート（CategorySheet）を開く。VoiceOver では 1 つの要素として読む。
//  文字が大きいときは、選ばれ方の文言を 2 行目に下げる。
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
                    status
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
        .accessibilityIdentifier("compose.category.change")
    }

    private var sparkle: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Palette.accent)
            .accessibilityHidden(true)
    }

    private var tag: some View {
        Text(category.title)
            .font(.zenMaruGothic(.bold, size: 13, relativeTo: .callout))
            .foregroundStyle(Palette.accentDeep)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .frame(minHeight: tagHeight)
            .background {
                Capsule()
                    .fill(Palette.card)
                    .stroke(Palette.accent, lineWidth: 1.5)
            }
            .fixedSize()
    }

    private var status: some View {
        Text(source.statusText)
            .kobosuMetaLabel()
            .fixedSize(horizontal: false, vertical: true)
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
