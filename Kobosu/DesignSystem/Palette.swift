//
//  Palette.swift
//  Kobosu
//
//  デザイン案（Issue #3）のカラーパレット。値は Assets.xcassets の Palette にあり、ライト／ダークで切り替わる。
//  注意には赤を使わず caution（#DE52B0）を使う。
//

import SwiftUI

enum Palette {
    /// 背景（#FBFAF7）
    static let paper = Color(.paper)
    /// カード（#FFFFFF）
    static let card = Color(.card)
    /// 文字（#19171F）
    static let ink = Color(.ink)
    /// 補足の文字（#6B6775）
    static let inkSecondary = Color(.inkSecondary)
    /// アクセント（#A100FF）。AccentColor と同じ
    static let accent = Color.accentColor
    /// 濃い紫（#7400C2）。やさしい面の上の文字など
    static let accentDeep = Color(.accentDeep)
    /// 選択・やさしい面（#F4E9FF）
    static let lavender = Color(.lavender)
    /// 注意（#DE52B0）
    static let caution = Color(.caution)
    /// 線（#D6D2C8）。アウトラインのボタンなど
    static let line = Color(.line)
    /// 押せない状態の面（#E6E3DB）
    static let disabledSurface = Color(.disabledSurface)
    /// 押せない状態の文字（#8A8592）
    static let disabledInk = Color(.disabledInk)
    /// セグメントの面（#EFECE5）
    static let segmentSurface = Color(.segmentSurface)

    /// グラデーションの色（#DE52B0 → #BE39D2 → #8B4FEA → #4B85FD）
    static let gradientColors = [
        Color(.gradientPink),
        Color(.gradientMagenta),
        Color(.gradientViolet),
        Color(.gradientBlue)
    ]

    /// グラデーション。「こぼす」ボタンなど、1 画面に 1 か所だけ使う
    static let gradient = LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
}

#Preview("パレット") {
    let swatches: [(String, Color)] = [
        ("paper", Palette.paper),
        ("card", Palette.card),
        ("ink", Palette.ink),
        ("inkSecondary", Palette.inkSecondary),
        ("accent", Palette.accent),
        ("accentDeep", Palette.accentDeep),
        ("lavender", Palette.lavender),
        ("caution", Palette.caution),
        ("line", Palette.line),
        ("disabledSurface", Palette.disabledSurface),
        ("disabledInk", Palette.disabledInk),
        ("segmentSurface", Palette.segmentSurface)
    ]
    ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(swatches, id: \.0) { name, color in
                HStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                        .stroke(Palette.line)
                        .frame(width: 44, height: 44)
                    Text(verbatim: name)
                        .foregroundStyle(Palette.ink)
                }
            }
            Capsule()
                .fill(Palette.gradient)
                .frame(height: 50)
        }
        .padding()
    }
    .background(Palette.paper)
}
