//
//  AppMark.swift
//  Kobosu
//
//  アプリのしるし（アイコンと「こぼす」）。ロック画面と、アプリスイッチャーで中身を覆うときに出す。
//  グラデーションは 1 画面 1 か所なので、gradient を true にできるのは、ほかにグラデーションの無い画面だけ。
//

import SwiftUI

struct AppMark: View {
    var gradient = false

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: iconSize * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background {
                    RoundedRectangle(cornerRadius: iconSize * 0.28, style: .continuous)
                        .fill(gradient ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Palette.accent))
                }
            Text("こぼす")
                .font(.kobosuHeadline)
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HStack(spacing: 32) {
        AppMark()
        AppMark(gradient: true)
    }
    .padding()
    .background(Palette.paper)
}
