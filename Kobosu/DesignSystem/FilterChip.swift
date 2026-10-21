//
//  FilterChip.swift
//  Kobosu
//
//  フィルターチップ（COMPONENTS 2/3）。高さ 30pt・13pt。選択中は Ink の塗り。タップ領域は 44pt。
//

import SwiftUI

struct FilterChip: View {
    let title: LocalizedStringResource
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 30

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.kobosuCallout)
                .foregroundStyle(isSelected ? Palette.paper : Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(minHeight: height)
                .background {
                    if isSelected {
                        Capsule().fill(Palette.ink)
                    } else {
                        Capsule().fill(Palette.card)
                            .stroke(Palette.line, lineWidth: 1)
                    }
                }
                .frame(minHeight: KobosuButtonStyle.minimumTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        FilterChip(title: "すべて", isSelected: true) {}
        FilterChip(title: "子育て", isSelected: false) {}
    }
    .padding()
    .background(Palette.paper)
}
