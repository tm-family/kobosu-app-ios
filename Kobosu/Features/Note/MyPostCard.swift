//
//  MyPostCard.swift
//  Kobosu
//
//  ノート（共有した）の自分の投稿のカード（デザイン案 SCREEN 04）。
//  「うちも同じ」の人数を大きく出し、ほかのスタンプは内訳として小さく並べる。すぐ消すこともできる。
//

import SwiftUI

struct MyPostCard: View {
    let post: Post
    let now: Date
    /// 投稿を消している途中か（この投稿に限らない）。途中は「この投稿を消す」を押せない
    let isDeleting: Bool
    let deletionFailed: Bool
    let onDelete: () -> Void

    @State private var isConfirmingDeletion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    CategoryTag(title: post.category.title)
                    Spacer(minLength: 8)
                    Text(RemainingTime(post.remainingTime(at: now)).text)
                        .kobosuMetaLabel()
                }
                Text(post.body)
                    .font(.kobosuBody)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineSpacing(4)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                sameHere
                breakdown
            }
            .accessibilityElement(children: .combine)
            deleteButton
        }
        .kobosuCard()
    }

    /// 「うちも同じ」の人数。強調する数字はこれだけにする
    @ViewBuilder private var sameHere: some View {
        if post.sameHereCount > 0 {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(verbatim: "\(post.sameHereCount)")
                        .roundedFont(size: 48, weight: .black, relativeTo: .largeTitle)
                        .foregroundStyle(Palette.accent)
                    Text("人が「うちも同じ」")
                        .font(.kobosuHeadline)
                        .foregroundStyle(Palette.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(post.sameHereCount)人が「うちも同じ」"))
                Text("あなただけじゃないよ。")
                    .font(.kobosuSubheadline)
                    .foregroundStyle(Palette.ink)
            }
        } else {
            Text("「うちも同じ」が届くと、ここに人数が出ます")
                .kobosuMetaLabel()
        }
    }

    /// 「うちも同じ」以外のスタンプの内訳（「わかる 24 · しんどいね 12」）。届いていないスタンプは出さない
    @ViewBuilder private var breakdown: some View {
        let others = EmpathyStamp.allCases.filter { $0 != .sameHere && post.count(of: $0) > 0 }
        if !others.isEmpty {
            Text(verbatim: others.map { "\(String(localized: $0.title)) \(post.count(of: $0))" }.joined(separator: " · "))
                .kobosuMetaLabel()
        }
    }

    private var deleteButton: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                isConfirmingDeletion = true
            } label: {
                Text("この投稿を消す")
            }
            .buttonStyle(.kobosuDestructiveText)
            .disabled(isDeleting)
            .accessibilityIdentifier("note.delete.\(post.id)")
            .confirmationDialog(
                Text("この投稿を消しますか？"),
                isPresented: $isConfirmingDeletion,
                titleVisibility: .visible
            ) {
                // 赤（destructive）にしないため、role は付けない
                Button {
                    onDelete()
                } label: {
                    Text("消す")
                }
                Button(role: .cancel) {} label: {
                    Text("キャンセル")
                }
            } message: {
                Text("届いた共感も一緒に消えて、もとに戻せません。")
            }
            if deletionFailed {
                Text("消せませんでした。時間をおいて、もう一度ためせます。")
                    .font(.kobosuCaption)
                    .foregroundStyle(Palette.caution)
            }
        }
    }
}

#Preview {
    let now = Date()
    ScrollView {
        VStack(spacing: 12) {
            MyPostCard(
                post: Post(
                    id: "a",
                    body: "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。",
                    category: .partner,
                    createdAt: now.addingTimeInterval(-18 * 60 * 60),
                    stampCounts: [.understand: 24, .hardDay: 12, .sameHere: 41, .wellDone: 8]
                ),
                now: now,
                isDeleting: false,
                deletionFailed: false
            ) {}
            MyPostCard(
                post: Post(id: "b", body: "今日も黙って洗い物をした。", category: .housework, createdAt: now),
                now: now,
                isDeleting: false,
                deletionFailed: true
            ) {}
        }
        .padding()
    }
    .background(Palette.paper)
}
