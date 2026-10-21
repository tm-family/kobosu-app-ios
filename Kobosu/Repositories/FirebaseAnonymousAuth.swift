//
//  FirebaseAnonymousAuth.swift
//  Kobosu
//
//  Firebase の匿名認証。アカウント登録の代わりに、サーバー上で自分の投稿を見分けるのに使う。
//  サインインした状態は Firebase Auth が Keychain に保存するので、再インストールしても同じ uid になる。
//

import FirebaseAuth
import Foundation

/// サインインを 1 つずつ行う（同時に呼ばれても匿名ユーザーを 2 人作らない）
actor FirebaseAnonymousAuth {
    private var signingIn: Task<String, any Error>?

    /// サインインした匿名ユーザーの uid。まだならサインインする
    func userID() async throws -> String {
        if let signingIn {
            return try await signingIn.value
        }
        let task = Task { try await Self.signInIfNeeded() }
        signingIn = task
        defer { signingIn = nil }
        return try await task.value
    }

    nonisolated private static func signInIfNeeded() async throws -> String {
        if let uid = Auth.auth().currentUser?.uid {
            return uid
        }
        return try await Auth.auth().signInAnonymously().user.uid
    }
}
