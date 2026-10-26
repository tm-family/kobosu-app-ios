//
//  WelcomeView.swift
//  Kobosu
//
//  初回起動の「ようこそ」（デザイン案 05）。3 つの約束を最初に伝える。登録は不要。
//

import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(spacing: 24) {
                    // グラデーションは「はじめる」のボタンの 1 か所にするため、アイコンは単色にする
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: iconSize * 0.45, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: iconSize, height: iconSize)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: iconSize * 0.28, style: .continuous))
                        .accessibilityHidden(true)
                        .padding(.top, 48)
                    VStack(spacing: 8) {
                        Text("そっと、こぼしていい。")
                            .font(.kobosuTitle)
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("義理の親のこと、家庭のこと。\n名前のない場所に、置いていこう。")
                            .font(.kobosuBody)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .multilineTextAlignment(.center)
                    VStack(spacing: 8) {
                        promise("名前もフォロワーもない")
                        promise("返ってくるのは共感だけ")
                        promise("投稿は24時間で消える")
                    }
                }
                .padding(.horizontal, 24)
            }
            Button(action: onStart) {
                Text("はじめる")
            }
            .buttonStyle(.kobosuPrimary)
            .accessibilityIdentifier("onboarding.start")
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .floralBackground()
    }

    private func promise(_ text: LocalizedStringResource) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(text)
                .font(.zenMaruGothic(.bold, size: 15, relativeTo: .body))
                .foregroundStyle(Palette.ink)
        }
        .kobosuCard(padding: 14)
    }
}

#Preview {
    WelcomeView {}
}
