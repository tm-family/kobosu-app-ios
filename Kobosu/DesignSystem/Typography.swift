//
//  Typography.swift
//  Kobosu
//
//  文字のスタイル。和文は同梱の Zen Maru Gothic、数字と欧文は SF Pro Rounded を使う。
//  どれも Dynamic Type で拡大縮小する（relativeTo の TextStyle に合わせて大きさが変わる）。
//  フォントは Info.plist の UIAppFonts で登録している。
//

import SwiftUI

/// 同梱している Zen Maru Gothic のウェイト。rawValue は PostScript 名
nonisolated enum ZenMaruGothic: String, CaseIterable, Sendable {
    case regular = "ZenMaruGothic-Regular"
    case medium = "ZenMaruGothic-Medium"
    case bold = "ZenMaruGothic-Bold"
}

extension Font {
    /// Zen Maru Gothic。size は Dynamic Type が標準のときの大きさ
    static func zenMaruGothic(_ weight: ZenMaruGothic, size: CGFloat, relativeTo textStyle: TextStyle) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: textStyle)
    }

    /// Large Title（32pt Bold）。画面の見出し
    static let kobosuLargeTitle = zenMaruGothic(.bold, size: 32, relativeTo: .largeTitle)
    /// Title（20pt Bold）。シートやカードの見出し
    static let kobosuTitle = zenMaruGothic(.bold, size: 20, relativeTo: .title3)
    /// 17pt Bold。大きいボタン・ナビゲーションバーの見出し
    static let kobosuHeadline = zenMaruGothic(.bold, size: 17, relativeTo: .headline)
    /// 14pt Bold。小さいボタン
    static let kobosuSubheadline = zenMaruGothic(.bold, size: 14, relativeTo: .subheadline)
    /// Body（15pt Regular）。投稿の本文など
    static let kobosuBody = zenMaruGothic(.regular, size: 15, relativeTo: .body)
    /// 13pt Regular。フィルターのチップ
    static let kobosuCallout = zenMaruGothic(.regular, size: 13, relativeTo: .callout)
    /// Caption（12pt Medium）。残り時間などの補足
    static let kobosuCaption = zenMaruGothic(.medium, size: 12, relativeTo: .caption)

    /// 数字と欧文（SF Pro Rounded）。TextStyle の標準の大きさで使う
    static func kobosuRounded(_ textStyle: TextStyle, weight: Weight = .regular) -> Font {
        .system(textStyle, design: .rounded, weight: weight)
    }
}

/// 数字と欧文（SF Pro Rounded）を決まった大きさで使い、Dynamic Type に合わせて拡大縮小する
private struct RoundedFontModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight

    init(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: .rounded))
    }
}

extension View {
    /// 数字と欧文（SF Pro Rounded）。size は Dynamic Type が標準のときの大きさ（例: 共感の人数は 48pt Black）
    func roundedFont(size: CGFloat, weight: Font.Weight, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(RoundedFontModifier(size: size, weight: weight, relativeTo: textStyle))
    }
}

#Preview("文字") {
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "きく")
                .font(.kobosuLargeTitle)
            Text(verbatim: "気持ちを送る")
                .font(.kobosuTitle)
            Text(verbatim: "送る")
                .font(.kobosuHeadline)
            Text(verbatim: "伏せ字にする")
                .font(.kobosuSubheadline)
            Text(verbatim: "今日も黙って洗い物をした。")
                .font(.kobosuBody)
            Text(verbatim: "すべて")
                .font(.kobosuCallout)
            Text(verbatim: "残り 22時間")
                .font(.kobosuCaption)
                .foregroundStyle(Palette.inkSecondary)
            Text(verbatim: "41")
                .roundedFont(size: 48, weight: .black, relativeTo: .largeTitle)
                .foregroundStyle(Palette.accent)
        }
        .foregroundStyle(Palette.ink)
        .padding()
    }
    .background(Palette.paper)
}
