//
//  PostCard.swift
//  Kobosu
//
//  タイムラインの投稿カード。投稿者が分かる表示は置かない（名前のない場所）。コメント欄も置かない。
//  強調する数字は「うちも同じ」の人数だけにする。
//

import SwiftUI

struct PostCard: View {
    let post: Post
    let sentStamps: Set<EmpathyStamp>
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                CategoryTag(title: post.category.title)
                Spacer(minLength: 8)
                Text(RemainingTime(post.remainingTime(at: now)).text)
                    .kobosuMetaLabel()
            }
            Text(post.body)
                .font(.kobosuBody)
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            stamps
            if sentStamps.contains(.sameHere) {
                Group {
                    if post.sameHereCount > 1 {
                        Text("あなたを含む\(post.sameHereCount)人が「うちも同じ」")
                    } else {
                        Text("あなたが「うちも同じ」を送りました")
                    }
                }
                .kobosuMetaLabel()
            }
        }
        .kobosuCard()
        .accessibilityElement(children: .combine)
    }

    /// 送られたスタンプだけを並べる。横に入りきらない（大きな文字サイズ）ときは縦に並べる
    @ViewBuilder private var stamps: some View {
        let sent = EmpathyStamp.allCases.filter { post.count(of: $0) > 0 }
        if !sent.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    stampChips(sent)
                }
                VStack(alignment: .leading, spacing: 8) {
                    stampChips(sent)
                }
            }
        }
    }

    private func stampChips(_ stamps: [EmpathyStamp]) -> some View {
        ForEach(stamps) { stamp in
            StampChip(stamp: stamp, count: post.count(of: stamp), isSent: sentStamps.contains(stamp))
        }
    }
}

#Preview {
    let now = Date()
    ScrollView {
        VStack(spacing: 12) {
            PostCard(
                post: Post(
                    id: "a",
                    body: "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。",
                    category: .partner,
                    createdAt: now.addingTimeInterval(-2 * 60 * 60),
                    stampCounts: [.understand: 24, .hardDay: 12, .sameHere: 41]
                ),
                sentStamps: [.sameHere],
                now: now
            )
            PostCard(
                post: Post(id: "b", body: "今日も黙って洗い物をした。", category: .housework, createdAt: now.addingTimeInterval(-23.5 * 60 * 60)),
                sentStamps: [],
                now: now
            )
        }
        .padding()
    }
    .background(Palette.paper)
}
