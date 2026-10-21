//
//  PostCompleteView.swift
//  Kobosu
//
//  投稿完了（デザイン案 09）。「こぼせた」ことをねぎらい、消える時間と、共感の届き方を伝える。
//  お知らせ（通知）は次の段階なので、共感はノートで見られることを伝える。
//

import SwiftUI

struct PostCompleteView: View {
    let post: Post
    /// 「きくに戻る」・「閉じる」
    let onClose: () -> Void
    /// 「続けてこぼす」
    let onContinue: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 88

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark")
                        .font(.system(size: iconSize * 0.4, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: iconSize, height: iconSize)
                        .background(Palette.lavender, in: Circle())
                        .accessibilityHidden(true)
                        .padding(.top, 32)
                    VStack(spacing: 8) {
                        Text("こぼせました")
                            .font(.kobosuTitle)
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("おつかれさま。24時間たつと、自動で消えます。")
                            .font(.kobosuBody)
                            .foregroundStyle(Palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    postCard
                    Text("共感が届いたら、ノートで見られます")
                        .font(.kobosuSubheadline)
                        .foregroundStyle(Palette.accentDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Palette.lavender, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
            }
            VStack(spacing: 4) {
                Button(action: onClose) {
                    Text("きくに戻る")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.kobosuSecondary)
                .accessibilityIdentifier("complete.back")
                Button(action: onContinue) {
                    Text("続けてこぼす")
                }
                .buttonStyle(.kobosuText)
                .accessibilityIdentifier("complete.continue")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Palette.paper)
        .navigationTitle(Text("こぼす"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) {
                    Text("閉じる")
                }
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityIdentifier("complete.close")
            }
        }
    }

    /// 投稿した内容（伏せ字にした後の本文）
    private var postCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                CategoryTag(title: post.category.title)
                Spacer(minLength: 8)
                Text(RemainingTime(post.remainingTime(at: .now)).text)
                    .kobosuMetaLabel()
            }
            Text(post.body)
                .font(.kobosuBody)
                .foregroundStyle(Palette.inkSecondary)
                .lineSpacing(4)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .kobosuCard()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        PostCompleteView(
            post: Post(
                id: "a",
                body: "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。",
                category: .partner,
                createdAt: .now
            ),
            onClose: {},
            onContinue: {}
        )
    }
}
