//
//  ListenView.swift
//  Kobosu
//
//  「きく」タブのタイムライン（デザイン案 SCREEN 01）。カテゴリで絞り込んで、他の人の投稿を読む。
//  開いたままでも 1 分ごとに残り時間を更新し、期限を過ぎた投稿は表示から外す。
//  他の人の投稿をタップすると、共感を送るハーフシートを開く。
//

import SwiftUI

struct ListenView: View {
    /// 変わると読み直す（投稿した後など）
    let reloadID: Int

    @State private var model: TimelineViewModel
    /// 共感を送るシートで開いている投稿
    @State private var selectedPost: Post?

    init(repository: any PostRepository, reports: any ReportRepository, reloadID: Int = 0) {
        self.reloadID = reloadID
        _model = State(initialValue: TimelineViewModel(repository: repository, reports: reports))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("今日も、おつかれさま。")
                        .kobosuMetaLabel()
                    categoryFilter
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Palette.paper)
            .navigationTitle(Text("きく"))
            .refreshable {
                await model.load()
            }
            .task(id: reloadID) {
                await model.load()
            }
            .sheet(item: $selectedPost) { post in
                EmpathySheet(post: model.post(id: post.id) ?? post, sentStamps: model.sentStamps(for: post)) { stamp in
                    try await model.send(stamp, to: post)
                }
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "すべて", isSelected: model.selectedCategory == nil) {
                    Task { await model.select(nil) }
                }
                ForEach(PostCategory.allCases) { category in
                    FilterChip(title: category.title, isSelected: model.selectedCategory == category) {
                        Task { await model.select(category) }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
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
                    message("いまは、ここに投稿がありません。")
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(posts) { post in
                            card(post, now: context.date)
                        }
                    }
                }
            }
        }
    }

    /// 他の人の投稿はタップで共感を送るシートを開く。自分の投稿には送れないので開かない
    @ViewBuilder private func card(_ post: Post, now: Date) -> some View {
        let card = PostCard(post: post, sentStamps: model.sentStamps(for: post), now: now)
        if model.isMine(post) {
            card
        } else {
            Button {
                selectedPost = post
            } label: {
                card
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("共感を送る画面を開きます"))
            .accessibilityIdentifier("post.\(post.id)")
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
    let repository = InMemoryPostRepository.preview()
    ListenView(repository: repository, reports: repository)
}

#Preview("投稿なし") {
    let repository = InMemoryPostRepository()
    ListenView(repository: repository, reports: repository)
}
