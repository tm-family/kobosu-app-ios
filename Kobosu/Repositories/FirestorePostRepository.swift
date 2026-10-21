//
//  FirestorePostRepository.swift
//  Kobosu
//
//  PostRepository の Firestore の実装。GoogleService-Info.plist があって Firebase を設定したときだけ使う。
//  文書の形と、期限をサーバーの時刻から決める手順は PostDocument に書いた。
//

import FirebaseFirestore
import Foundation

nonisolated enum FirestoreRepositoryError: Error, Equatable {
    /// 作った投稿にサーバーの時刻が入っていない
    case missingServerTimestamp
    /// Firestore ではまだ使えない（共感はタスク 20、削除はタスク 22 で実装する）
    case notSupportedYet
}

final class FirestorePostRepository: PostRepository {
    private let identity: AnonymousIDStore
    private let auth: FirebaseAnonymousAuth
    private let now: () -> Date

    init(
        identity: AnonymousIDStore,
        auth: FirebaseAnonymousAuth = FirebaseAnonymousAuth(),
        now: @escaping () -> Date = { Date() }
    ) {
        self.identity = identity
        self.auth = auth
        self.now = now
    }

    func timeline(category: PostCategory?) async throws -> [Post] {
        // 読み出しもサインインした人だけにする（ルールはタスク 23）
        _ = try await userID()
        return try await FirestorePostAPI.timeline(category: category, now: now())
    }

    func submit(body: String, category: PostCategory) async throws -> Post {
        let body = try Post.validatedBody(body)
        let uid = try await userID()
        return try await FirestorePostAPI.submit(body: body, category: category, uid: uid)
    }

    func myPosts() async throws -> [Post] {
        let uid = try await userID()
        return try await FirestorePostAPI.myPosts(uid: uid, now: now())
    }

    func delete(postID: Post.ID) async throws {
        throw FirestoreRepositoryError.notSupportedYet
    }

    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {
        throw FirestoreRepositoryError.notSupportedYet
    }

    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> {
        throw FirestoreRepositoryError.notSupportedYet
    }

    /// 匿名認証の uid。Keychain の匿名 ID としても控える
    private func userID() async throws -> String {
        let uid = try await auth.userID()
        try identity.replaceID(with: uid)
        return uid
    }
}

/// Firestore を読み書きする部分。Firestore の型は外に出さず、Post にして返す
nonisolated private enum FirestorePostAPI {
    private typealias Field = PostDocument.Field

    private static var database: Firestore {
        Firestore.firestore()
    }

    private static func ownPosts(uid: String) -> CollectionReference {
        database
            .collection(PostDocument.usersCollection)
            .document(uid)
            .collection(PostDocument.ownPostsCollection)
    }

    /// 期限内の投稿を新しい順に。expireAt は createdAt の 24 時間後なので、expireAt の順は作った順と同じ
    static func timeline(category: PostCategory?, now: Date) async throws -> [Post] {
        var query = database
            .collection(PostDocument.postsCollection)
            .whereField(Field.expireAt, isGreaterThan: Timestamp(date: now))
        if let category {
            query = query.whereField(Field.category, isEqualTo: category.rawValue)
        }
        let snapshot = try await query
            .order(by: Field.expireAt, descending: true)
            .limit(to: PostDocument.timelineLimit)
            .getDocuments()
        return PostDocument.activePosts(snapshot.documents.compactMap(post(from:)), at: now)
    }

    /// 2 段で書く（PostDocument のコメント）。投稿と自分の投稿の目印は、どちらも同じバッチで書く
    static func submit(body: String, category: PostCategory, uid: String) async throws -> Post {
        let postRef = database.collection(PostDocument.postsCollection).document()
        let ownRef = ownPosts(uid: uid).document(postRef.documentID)
        let serverTimes: [String: Any] = [
            Field.createdAt: FieldValue.serverTimestamp(),
            Field.expireAt: FieldValue.serverTimestamp()
        ]
        let create = database.batch()
        create.setData(
            PostDocument.newPostFields(body: body, category: category).merging(serverTimes) { $1 },
            forDocument: postRef
        )
        create.setData(serverTimes, forDocument: ownRef)
        try await create.commit()

        let created = try await postRef.getDocument(source: .server)
        guard let createdAt = created.get(Field.createdAt) as? Timestamp else {
            throw FirestoreRepositoryError.missingServerTimestamp
        }
        // Date に直すと端数が丸まるので、Timestamp のまま 24 時間足す（ルールで createdAt + 24 時間と比べるため）
        let expireAt = Timestamp(seconds: createdAt.seconds + Int64(Post.lifetime), nanoseconds: createdAt.nanoseconds)
        let update = database.batch()
        update.updateData([Field.expireAt: expireAt], forDocument: postRef)
        update.updateData([Field.expireAt: expireAt], forDocument: ownRef)
        try await update.commit()

        return Post(
            id: postRef.documentID,
            body: body,
            category: category,
            createdAt: createdAt.dateValue(),
            expireAt: expireAt.dateValue()
        )
    }

    /// 自分の投稿の目印から、期限内の投稿を読む
    static func myPosts(uid: String, now: Date) async throws -> [Post] {
        let marks = try await ownPosts(uid: uid)
            .whereField(Field.expireAt, isGreaterThan: Timestamp(date: now))
            .getDocuments()
        let ids = marks.documents.map(\.documentID)
        let posts = try await withThrowingTaskGroup(of: Post?.self) { group in
            for id in ids {
                group.addTask { try await post(id: id) }
            }
            var posts: [Post] = []
            for try await post in group {
                if let post {
                    posts.append(post)
                }
            }
            return posts
        }
        return PostDocument.activePosts(posts, at: now)
    }

    /// 1 件読む。消えていたら nil
    private static func post(id: String) async throws -> Post? {
        let snapshot = try await database.collection(PostDocument.postsCollection).document(id).getDocument()
        guard let data = snapshot.data() else {
            return nil
        }
        return post(id: snapshot.documentID, data: data)
    }

    private static func post(from document: QueryDocumentSnapshot) -> Post? {
        post(id: document.documentID, data: document.data())
    }

    private static func post(id: String, data: [String: Any]) -> Post? {
        PostDocument.post(
            id: id,
            data: data,
            createdAt: (data[Field.createdAt] as? Timestamp)?.dateValue(),
            expireAt: (data[Field.expireAt] as? Timestamp)?.dateValue()
        )
    }
}
