//
//  NoteView.swift
//  Kobosu
//
//  「ノート」タブ（デザイン案 SCREEN 04）。自分が共有した投稿と、届いた「うちも同じ」の人数・スタンプの内訳を見返す。
//  今回は「共有した」だけなので、「共有した／自分だけ」のセグメントは出さない（使えない機能を見せない）。
//  開いたままでも 1 分ごとに残り時間を更新し、期限を過ぎた投稿は表示から外す。
//

import SwiftUI

struct NoteView: View {
    @State private var model: NoteViewModel

    init(repository: any PostRepository) {
        _model = State(initialValue: NoteViewModel(repository: repository))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("共有した投稿")
                        .font(.zenMaruGothic(.bold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.inkSecondary)
                        .accessibilityAddTraits(.isHeader)
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.paper)
            .navigationTitle(Text("ノート"))
            .refreshable {
                await model.load()
            }
            // タブを開くたびに読み直す（投稿した後や、時間がたって共感が増えたとき）
            .task {
                await model.load()
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 200)
        case .failed:
            message("読み込めませんでした。下に引っぱると、もう一度読み込みます。")
        case .loaded:
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let posts = model.visiblePosts(at: context.date)
                if posts.isEmpty {
                    message("共有した投稿は、ここに出ます。24時間たつと、自動で消えます。")
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(posts) { post in
                            MyPostCard(
                                post: post,
                                now: context.date,
                                // どれかを消している間は、ほかの投稿の「消す」も押せなくする
                                isDeleting: model.deleting != nil,
                                deletionFailed: model.failedDeletion == post.id
                            ) {
                                Task { await model.delete(post) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func message(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.kobosuBody)
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    let identity = InMemoryAnonymousIDStore(id: "me")
    let repository = InMemoryPostRepository.preview(identity: identity)
    repository.seed(
        Post(
            id: "mine-0",
            body: "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。",
            category: .partner,
            createdAt: Date().addingTimeInterval(-18 * 60 * 60),
            stampCounts: [.understand: 24, .hardDay: 12, .sameHere: 41, .wellDone: 8]
        ),
        authorID: "me"
    )
    repository.seed(Post(id: "mine-1", body: "今日も黙って洗い物をした。", category: .housework, createdAt: Date()), authorID: "me")
    return NoteView(repository: repository)
}

#Preview("投稿なし") {
    NoteView(repository: InMemoryPostRepository())
}
