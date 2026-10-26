//
//  InMemoryPostRepository.swift
//  Kobosu
//
//  PostRepository と ReportRepository のインメモリ実装。テスト・Preview・撮影モードで使う。
//  データはメモリ上にだけ持ち、アプリを終えると消える。
//

import Foundation

final class InMemoryPostRepository: PostRepository, ReportRepository {
    /// 投稿と、他の人には見せない付随の情報（投稿者・共感・通報）
    private struct Record {
        var post: Post
        let authorID: String
        /// スタンプごとの送った人の匿名 ID
        var stampSenders: [EmpathyStamp: Set<String>] = [:]
        var reporterIDs: Set<String> = []
    }

    private var records: [Post.ID: Record] = [:]
    private var hiddenPostIDs: Set<Post.ID> = []
    private let identity: AnonymousIDStore
    private let now: () -> Date
    private let makePostID: () -> String

    init(
        identity: AnonymousIDStore = InMemoryAnonymousIDStore(),
        now: @escaping () -> Date = { Date() },
        makePostID: @escaping () -> String = { UUID().uuidString }
    ) {
        self.identity = identity
        self.now = now
        self.makePostID = makePostID
    }

    /// 他の人の投稿を置く（テスト・デモデータ用）。stampCounts の人数ぶん、架空の人が送ったことにする
    func seed(_ post: Post, authorID: String = "someone") {
        var record = Record(post: post, authorID: authorID)
        for (stamp, count) in post.stampCounts where count > 0 {
            record.stampSenders[stamp] = Set((0..<count).map { "seed-\(post.id)-\(stamp.rawValue)-\($0)" })
        }
        records[post.id] = record
    }

    // MARK: - PostRepository

    func timeline(category: PostCategory?) async throws -> [Post] {
        let date = now()
        return records.values
            .filter { record in
                !record.post.isExpired(at: date)
                    && record.reporterIDs.count < ReportPolicy.autoHideThreshold
                    && !hiddenPostIDs.contains(record.post.id)
                    && (category == nil || record.post.category == category)
            }
            .map(\.post)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        let trimmed = try Post.validatedBody(body)
        let myID = try identity.currentID()
        let post = Post(id: makePostID(), body: trimmed, category: category, createdAt: now())
        records[post.id] = Record(post: post, authorID: myID)
        return post
    }

    func myPosts() async throws -> [Post] {
        let myID = try identity.currentID()
        let date = now()
        return records.values
            .filter { $0.authorID == myID && !$0.post.isExpired(at: date) }
            .map(\.post)
            .sorted { $0.createdAt > $1.createdAt }
    }

    func delete(postID: Post.ID) async throws {
        let record = try activeRecord(postID)
        let myID = try identity.currentID()
        guard record.authorID == myID else {
            throw PostRepositoryError.notOwner
        }
        records[postID] = nil
    }

    func assignCategory(_ category: PostCategory, toPostID postID: Post.ID) async throws -> Post {
        var record = try activeRecord(postID)
        let myID = try identity.currentID()
        guard record.authorID == myID else {
            throw PostRepositoryError.notOwner
        }
        record.post = try record.post.assigningCategory(category)
        records[postID] = record
        return record.post
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        var record = try activeRecord(postID)
        let myID = try identity.currentID()
        guard record.authorID != myID else {
            throw PostRepositoryError.ownPost
        }
        record.stampSenders[stamp, default: []].insert(myID)
        record.post.stampCounts[stamp] = record.stampSenders[stamp]?.count
        records[postID] = record
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        let record = try activeRecord(postID)
        let myID = try identity.currentID()
        return Set(record.stampSenders.filter { $0.value.contains(myID) }.keys)
    }

    func deleteAllMyData() async throws {
        let myID = try identity.currentID()
        var remaining: [Post.ID: Record] = [:]
        for (postID, record) in records where record.authorID != myID {
            var record = record
            record.reporterIDs.remove(myID)
            for stamp in EmpathyStamp.allCases {
                record.stampSenders[stamp]?.remove(myID)
                let count = record.stampSenders[stamp]?.count ?? 0
                record.post.stampCounts[stamp] = count > 0 ? count : nil
            }
            remaining[postID] = record
        }
        records = remaining
        hiddenPostIDs = []
    }

    // MARK: - ReportRepository

    func report(postID: Post.ID, reason: ReportReason) async throws {
        var record = try activeRecord(postID)
        let myID = try identity.currentID()
        guard record.authorID != myID else {
            throw PostRepositoryError.ownPost
        }
        record.reporterIDs.insert(myID)
        records[postID] = record
    }

    func hide(postID: Post.ID) async throws {
        hiddenPostIDs.insert(postID)
    }

    // MARK: -

    /// 期限内の投稿。無い・期限切れなら postNotFound
    private func activeRecord(_ postID: Post.ID) throws -> Record {
        guard let record = records[postID], !record.post.isExpired(at: now()) else {
            throw PostRepositoryError.postNotFound
        }
        return record
    }
}

extension InMemoryPostRepository {
    /// Preview・撮影モード用。他の人の投稿をいくつか置いたもの（実在の人名・地名は書かない）。
    /// 撮影は言語ごとに行うので、本文は String Catalog から表示の言語で読む。
    /// 時計は呼び出した時刻で止めるので、Repository の中では期限切れにならない（画面の表示は実際の時刻で外れていく）
    static func preview(now: Date = Date(), identity: AnonymousIDStore = InMemoryAnonymousIDStore()) -> InMemoryPostRepository {
        let repository = InMemoryPostRepository(identity: identity, now: { now })
        func post(
            _ index: Int,
            _ body: String.LocalizationValue,
            _ category: PostCategory,
            hoursAgo: Double,
            _ counts: [EmpathyStamp: Int]
        ) -> Post {
            Post(
                id: "preview-\(index)",
                body: String(localized: body),
                category: category,
                createdAt: now.addingTimeInterval(-hoursAgo * 60 * 60),
                stampCounts: counts
            )
        }
        [
            post(0, "「手伝おうか」って言われるたびにモヤっとする。", .housework, hoursAgo: 2, [.sameHere: 41, .understand: 24]),
            post(1, "帰省のたびに「まだなの？」と聞かれる。笑ってかわすのにもう疲れた。", .inLaws, hoursAgo: 3, [.sameHere: 18, .hardDay: 9]),
            post(2, "寝かしつけに 2 時間。気づいたら自分の夕飯を食べそびれていた。", .parenting, hoursAgo: 5, [.wellDone: 12, .sameHere: 7]),
            post(3, "今日も黙って洗い物をした。", .partner, hoursAgo: 9, [.understand: 5]),
            post(4, "通院の付き添いで仕事を早退。誰にも言えないけど、正直しんどい。", .other, hoursAgo: 20, [:])
        ]
        .forEach { repository.seed($0) }
        return repository
    }
}
