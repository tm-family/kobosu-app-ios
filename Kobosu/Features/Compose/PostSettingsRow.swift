//
//  PostSettingsRow.swift
//  Kobosu
//
//  投稿画面の、公開範囲と消えるまでの 1 行（デザイン案 6 枚目「みんなに共有 · 24時間で消える ›」）。
//  公開範囲は「みんなに共有」だけ、消えるまでは 24 時間だけなので選ぶ UI は出さず、押すと説明のシート（PostSettingsSheet）を開く（Discussion #76 の Q5）。
//

import SwiftUI

struct PostSettingsRow: View {
    let onOpen: () -> Void

    private static let cornerRadius: CGFloat = 22

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Text("みんなに共有 · 24時間で消える")
                    .font(.kobosuBody)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(Palette.card)
                    .stroke(Palette.line)
            }
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("公開範囲と消えるまでの説明を開きます"))
        .accessibilityIdentifier("compose.settings")
    }
}

/// 公開範囲と消えるまでの説明。選べるのは今の 1 つずつなので、選ばれているものだけを出して説明する
struct PostSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(
                        title: "公開範囲",
                        value: "みんなに共有",
                        systemImage: "person.2",
                        description: "だれでも読めます。名前やアカウントは出ません。"
                    )
                    section(
                        title: "消えるまで",
                        value: "24時間で消える",
                        systemImage: "clock",
                        description: "24時間たつと、自動で消えます。あとから延ばすことはできません。"
                    )
                    Text("いまは、この設定で投稿します。")
                        .kobosuMetaLabel()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.paper)
            .navigationTitle(Text("投稿の設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityIdentifier("compose.settings.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func section(
        title: LocalizedStringResource,
        value: LocalizedStringResource,
        systemImage: String,
        description: LocalizedStringResource
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.zenMaruGothic(.bold, size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                    Text(value)
                        .font(.zenMaruGothic(.bold, size: 15, relativeTo: .body))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
                Text(description)
                    .font(.kobosuSubheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .kobosuCard(padding: 14)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isSelected)
        }
    }
}

#Preview("行") {
    PostSettingsRow {}
        .padding()
        .background(Palette.paper)
}

#Preview("説明のシート") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            PostSettingsSheet()
        }
}
