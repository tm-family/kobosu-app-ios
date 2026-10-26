//
//  PostCompleteView.swift
//  Kobosu
//
//  投稿完了（デザイン案 09）。「こぼせた」ことをねぎらい、消える時間と、共感の届き方を伝える。
//  お知らせ（通知）は次の段階なので、共感はノートで見られることを伝える。
//  未分類で投稿したときだけ、投稿カードの下でカテゴリを付けるようやさしく問いかける（付けなくても閉じられる。1 回だけ）。
//

import SwiftUI

struct PostCompleteView: View {
    /// 「きくに戻る」・「閉じる」
    let onClose: () -> Void
    /// 「続けてこぼす」
    let onContinue: () -> Void
    /// カテゴリを付けられたとき（タイムラインを読み直す）
    let onCategoryAssigned: (Post) -> Void

    @State private var model: PostCompleteViewModel
    /// カテゴリを選ぶシートを出しているか
    @State private var isChoosingCategory = false

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 88

    init(
        post: Post,
        repository: any PostRepository,
        lastCategories: any LastCategoryStore,
        onClose: @escaping () -> Void,
        onContinue: @escaping () -> Void,
        onCategoryAssigned: @escaping (Post) -> Void = { _ in }
    ) {
        self.onClose = onClose
        self.onContinue = onContinue
        self.onCategoryAssigned = onCategoryAssigned
        _model = State(initialValue: PostCompleteViewModel(post: post, repository: repository, lastCategories: lastCategories))
    }

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
                    if model.asksForCategory {
                        categoryPrompt
                    }
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
            // カテゴリを付けている途中は閉じさせない（付けられたかどうか分からなくなるため。数秒で終わる）
            .disabled(model.isAssigning)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .floralBackground()
        .navigationTitle(Text("こぼす"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onClose) {
                    Text("閉じる")
                }
                .foregroundStyle(Palette.inkSecondary)
                .disabled(model.isAssigning)
                .accessibilityIdentifier("complete.close")
            }
        }
        .interactiveDismissDisabled(model.isAssigning)
        .onChange(of: model.assignState) { _, state in
            announce(state)
        }
        .sheet(isPresented: $isChoosingCategory) {
            // 付けるときは 6 つから選ぶ（未分類には戻せない）
            CategorySheet(categories: model.assignableCategories, selection: nil) { category in
                Task {
                    if await model.assign(category) {
                        onCategoryAssigned(model.post)
                    }
                }
            }
        }
    }

    /// 未分類の投稿に、カテゴリを付けるようやさしく問いかける。付けなくてもよいことも伝える
    private var categoryPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("カテゴリを付けると、近い悩みの人に届きやすくなります")
                        .font(.kobosuSubheadline)
                        .foregroundStyle(Palette.ink)
                    Text("付けなくても、「すべて」には届いています")
                        .kobosuMetaLabel()
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            if model.assignState == .failed {
                Text("いまはカテゴリを付けられませんでした。このままでも、「すべて」には届いています。")
                    .font(.kobosuCaption)
                    .foregroundStyle(Palette.caution)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                isChoosingCategory = true
            } label: {
                HStack(spacing: 8) {
                    if model.isAssigning {
                        ProgressView()
                            .tint(Palette.accentDeep)
                    }
                    Text("カテゴリを付ける")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.kobosuTonal)
            .disabled(model.isAssigning)
            .accessibilityIdentifier("complete.assign")
        }
        .kobosuCard()
    }

    /// 付けられたか・付けられなかったかを VoiceOver で知らせる（問いかけが消える・文が出るだけでは伝わらないため）
    private func announce(_ state: PostCompleteViewModel.AssignState) {
        let message: LocalizedStringResource
        switch state {
        case .assigned:
            message = "カテゴリを付けました"
        case .failed:
            message = "いまはカテゴリを付けられませんでした。このままでも、「すべて」には届いています。"
        case .idle, .assigning:
            return
        }
        AccessibilityNotification.Announcement(String(localized: message)).post()
    }

    /// 投稿した内容（伏せ字にした後の本文）。カテゴリを付けたら、付けたカテゴリのタグを出す
    private var postCard: some View {
        let post = model.post
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let tagTitle = post.category.tagTitle {
                    CategoryTag(title: tagTitle)
                }
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

#Preview("カテゴリあり") {
    NavigationStack {
        PostCompleteView(
            post: Post(
                id: "a",
                body: "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。",
                category: .partner,
                createdAt: .now
            ),
            repository: InMemoryPostRepository(),
            lastCategories: InMemoryLastCategoryStore(),
            onClose: {},
            onContinue: {}
        )
    }
}

#Preview("未分類") {
    let repository = InMemoryPostRepository(identity: InMemoryAnonymousIDStore(id: "me"))
    let post = Post(id: "a", body: "今日はなんだか疲れた。", category: .uncategorized, createdAt: .now)
    repository.seed(post, authorID: "me")
    return NavigationStack {
        PostCompleteView(
            post: post,
            repository: repository,
            lastCategories: InMemoryLastCategoryStore(),
            onClose: {},
            onContinue: {}
        )
    }
}
