//
//  FloralBackground.swift
//  Kobosu
//
//  全画面に敷く花柄の背景（Discussion #76 の変更 2。見本 A「淡く大きく」）。背景色 Palette.paper のすぐ上に部品を置き、
//  カード・入力欄は白のまま上に重ねる。画面ごとに描かず、どの画面もこのビューを背景にする。
//  配置は FloralLayout（画面の大きさに合わせて端に寄せる）。花は飾りなので VoiceOver から隠し、タップも受けない。
//

import SwiftUI

struct FloralBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Palette.paper
                ForEach(Array(FloralLayout.placements(in: proxy.size).enumerated()), id: \.offset) { _, placement in
                    Image(placement.part.image)
                        .resizable()
                        .frame(width: placement.size.width, height: placement.size.height)
                        .rotationEffect(.degrees(placement.rotation))
                        .position(placement.center)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("iPhone") {
    FloralBackground()
}

#Preview("ダーク") {
    FloralBackground()
        .preferredColorScheme(.dark)
}

#Preview("カードを重ねる") {
    ZStack {
        FloralBackground()
        Text(verbatim: "カードは白のまま花の上に重ねる")
            .font(.kobosuBody)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kobosuCard()
            .padding()
    }
}
