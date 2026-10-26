//
//  FlowLayout.swift
//  Kobosu
//
//  チップを左から並べ、幅に収まらなくなったら次の行に折り返すレイアウト。
//  文字を大きくしても横にはみ出さない（1 つで幅を超えるものは、幅に合わせて置く）。
//

import SwiftUI

nonisolated struct FlowLayout: Layout {
    /// 横の間隔
    var spacing: CGFloat = 8
    /// 行と行の間隔
    var lineSpacing: CGFloat = 8

    private struct Arrangement {
        var frames: [CGRect] = []
        var size: CGSize = .zero
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(maxWidth: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, arrangement.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> Arrangement {
        var arrangement = Arrangement()
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            if cursorX > 0, cursorX + size.width > maxWidth {
                cursorX = 0
                cursorY += rowHeight + lineSpacing
                rowHeight = 0
            }
            arrangement.frames.append(CGRect(origin: CGPoint(x: cursorX, y: cursorY), size: size))
            arrangement.size.width = max(arrangement.size.width, cursorX + size.width)
            cursorX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        arrangement.size.height = cursorY + rowHeight
        return arrangement
    }
}

#Preview {
    FlowLayout {
        ForEach(PostCategory.filterable) { category in
            CategoryTag(title: category.title)
        }
    }
    .padding()
    .background(Palette.paper)
}
