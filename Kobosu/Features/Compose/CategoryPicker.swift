//
//  CategoryPicker.swift
//  Kobosu
//
//  投稿画面のカテゴリ選択（デザイン案 SCREEN 02）。カテゴリを 1 つだけ選ぶ。
//  選んだものは淡い紫の面と紫の線、それ以外はカードの面と線。並びは PostCategory の case の順。
//

import SwiftUI

struct CategoryPicker: View {
    @Binding var selection: PostCategory?

    var body: some View {
        // チップはタップ領域（44pt）が見た目（30pt）より大きく、それが行の間隔になるので、行の間隔は足さない
        FlowLayout(lineSpacing: 0) {
            ForEach(PostCategory.allCases) { category in
                CategoryChoiceChip(title: category.title, isSelected: selection == category) {
                    selection = category
                }
                .accessibilityIdentifier("compose.category.\(category.rawValue)")
            }
        }
    }
}

private struct CategoryChoiceChip: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 30

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isSelected ? .zenMaruGothic(.bold, size: 13, relativeTo: .callout) : .kobosuCallout)
                .foregroundStyle(isSelected ? Palette.accentDeep : Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: height)
                .background {
                    Capsule()
                        .fill(isSelected ? Palette.lavender : Palette.card)
                        .stroke(isSelected ? Palette.accent : Palette.line, lineWidth: isSelected ? 1.5 : 1)
                }
                .frame(minHeight: KobosuButtonStyle.minimumTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var selection: PostCategory? = .partner
    CategoryPicker(selection: $selection)
        .padding()
        .background(Palette.paper)
}
