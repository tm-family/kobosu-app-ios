//
//  StampChip.swift
//  Kobosu
//
//  共感スタンプ（小）（COMPONENTS 2/3）。高さ 30pt。自分が送った後は紫の線と面になる。
//

import SwiftUI

struct StampChip: View {
    let stamp: EmpathyStamp
    let count: Int
    let isSent: Bool

    @ScaledMetric(relativeTo: .callout) private var height: CGFloat = 30

    var body: some View {
        HStack(spacing: 6) {
            Text(stamp.title)
                .font(.zenMaruGothic(.medium, size: 13, relativeTo: .callout))
            Text(verbatim: "\(count)")
                .roundedFont(size: 13, weight: .semibold, relativeTo: .callout)
        }
        .foregroundStyle(isSent ? Palette.accentDeep : Palette.ink)
        .lineLimit(1)
        .padding(.horizontal, 12)
        .frame(minHeight: height)
        .background {
            if isSent {
                Capsule().fill(Palette.lavender)
                    .stroke(Palette.accent, lineWidth: 1.5)
            } else {
                Capsule().fill(Palette.card)
                    .stroke(Palette.line, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        // カードの中でまとめて読まれても伝わるよう、送ったかどうかは文で伝える
        .accessibilityLabel(
            isSent ? Text("\(String(localized: stamp.title))、\(count)人、送りました") : Text("\(String(localized: stamp.title))、\(count)人")
        )
    }
}

#Preview {
    VStack {
        StampChip(stamp: .understand, count: 24, isSent: false)
        StampChip(stamp: .sameHere, count: 41, isSent: true)
    }
    .padding()
    .background(Palette.paper)
}
