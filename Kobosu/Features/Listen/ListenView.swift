//
//  ListenView.swift
//  Kobosu
//
//  「きく」タブのタイムライン（デザイン案 SCREEN 01）。カテゴリで絞り込んで、他の人の投稿を読む。
//  開いたままでも 1 分ごとに残り時間を更新し、期限を過ぎた投稿は表示から外す。
//

import SwiftUI

struct ListenView: View {
    @State private var model: TimelineViewModel

    init(repository: any PostRepository) {
        _model = State(initialValue: TimelineViewModel(repository: repository))
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
            .task {
                await model.load()
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
                            PostCard(post: post, sentStamps: model.sentStamps(for: post), now: context.date)
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
    ListenView(repository: InMemoryPostRepository.preview())
}

#Preview("投稿なし") {
    ListenView(repository: InMemoryPostRepository())
}
