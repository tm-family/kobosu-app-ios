//
//  KobosuButtonStyle.swift
//  Kobosu
//
//  デザイン案（COMPONENTS 1/3）のボタン。形はどれも全丸で、タップ領域は最低 44pt にする。
//  押せない状態（.disabled）では、面のあるボタンは #E6E3DB の面と #8A8592 の文字になる。
//
//    Button("送る") { … }.buttonStyle(.kobosuPrimary)
//

import SwiftUI

struct KobosuButtonStyle: ButtonStyle {
    enum Kind {
        /// 高さ 50pt・17pt Bold・グラデーションの面。送る／はじめる。グラデーションは 1 画面 1 か所なので、1 画面に 1 つだけ置く
        case primary
        /// 高さ 30pt・14pt Bold・グラデーションの面。ナビゲーションバー用
        case primarySmall
        /// 高さ 44pt・Ink の面。確定／きくに戻る
        case secondary
        /// 線 1.5pt。もう一方の選択肢
        case outline
        /// 淡い紫の面＋濃い紫の文字。やさしい行動
        case tonal
        /// 背景なし・15pt。取り消し
        case text
        /// 背景なし・15pt・注意の色。削除の操作（赤は使わない）
        case destructiveText
    }

    /// タップ領域の最低の大きさ
    static let minimumTapSize: CGFloat = 44

    let kind: Kind

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: kind == .primary ? .infinity : nil, minHeight: height)
            .background { background }
            .frame(minWidth: Self.minimumTapSize, minHeight: Self.minimumTapSize)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var font: Font {
        switch kind {
        case .primary:
            .kobosuHeadline
        case .primarySmall:
            .kobosuSubheadline
        case .secondary, .outline, .tonal:
            .zenMaruGothic(.bold, size: 15, relativeTo: .body)
        case .text, .destructiveText:
            .kobosuBody
        }
    }

    private var height: CGFloat {
        switch kind {
        case .primary:
            50
        case .primarySmall:
            30
        case .secondary, .outline, .tonal, .text, .destructiveText:
            44
        }
    }

    private var horizontalPadding: CGFloat {
        switch kind {
        case .primary:
            24
        case .primarySmall:
            14
        case .secondary, .outline, .tonal:
            20
        case .text, .destructiveText:
            8
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary, .primarySmall:
            isEnabled ? .white : Palette.disabledInk
        case .secondary:
            isEnabled ? Palette.paper : Palette.disabledInk
        case .outline:
            isEnabled ? Palette.ink : Palette.disabledInk
        case .tonal:
            isEnabled ? Palette.accentDeep : Palette.disabledInk
        case .text:
            isEnabled ? Palette.inkSecondary : Palette.disabledInk
        case .destructiveText:
            isEnabled ? Palette.caution : Palette.disabledInk
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary, .primarySmall:
            if isEnabled {
                Capsule().fill(Palette.gradient)
            } else {
                Capsule().fill(Palette.disabledSurface)
            }
        case .secondary:
            Capsule().fill(isEnabled ? Palette.ink : Palette.disabledSurface)
        case .outline:
            Capsule().strokeBorder(Palette.line, lineWidth: 1.5)
        case .tonal:
            Capsule().fill(isEnabled ? Palette.lavender : Palette.disabledSurface)
        case .text, .destructiveText:
            Color.clear
        }
    }
}

extension ButtonStyle where Self == KobosuButtonStyle {
    static var kobosuPrimary: Self { KobosuButtonStyle(kind: .primary) }
    static var kobosuPrimarySmall: Self { KobosuButtonStyle(kind: .primarySmall) }
    static var kobosuSecondary: Self { KobosuButtonStyle(kind: .secondary) }
    static var kobosuOutline: Self { KobosuButtonStyle(kind: .outline) }
    static var kobosuTonal: Self { KobosuButtonStyle(kind: .tonal) }
    static var kobosuText: Self { KobosuButtonStyle(kind: .text) }
    static var kobosuDestructiveText: Self { KobosuButtonStyle(kind: .destructiveText) }
}

#Preview("ボタン") {
    ScrollView {
        VStack(spacing: 16) {
            Button {} label: { Text(verbatim: "送る") }
                .buttonStyle(.kobosuPrimary)
            Button {} label: { Text(verbatim: "投稿") }
                .buttonStyle(.kobosuPrimarySmall)
            Button {} label: { Text(verbatim: "伏せ字にする") }
                .buttonStyle(.kobosuSecondary)
            Button {} label: { Text(verbatim: "自分で書き直す") }
                .buttonStyle(.kobosuOutline)
            Button {} label: { Text(verbatim: "ありがとうを返す") }
                .buttonStyle(.kobosuTonal)
            Button {} label: { Text(verbatim: "キャンセル") }
                .buttonStyle(.kobosuText)
            Button {} label: { Text(verbatim: "この投稿を消す") }
                .buttonStyle(.kobosuDestructiveText)
            Button {} label: { Text(verbatim: "投稿") }
                .buttonStyle(.kobosuPrimary)
                .disabled(true)
            Button {} label: { Text(verbatim: "伏せ字にする") }
                .buttonStyle(.kobosuSecondary)
                .disabled(true)
        }
        .padding()
    }
    .background(Palette.paper)
}
