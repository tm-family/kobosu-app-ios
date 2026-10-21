//
//  DataEraser.swift
//  Kobosu
//
//  「すべてのデータを削除」。サーバー上の自分の投稿・共感・通報を消してから、端末の中の下書き・設定・「表示しない」・匿名 ID を破棄する。
//  サーバーを消せなかったときは、端末の中も消さずに止める（先に ID を消すと、サーバーに残った自分の投稿を消せなくなる）。
//

import Foundation

final class DataEraser {
    private let posts: any PostRepository
    private let identity: any AnonymousIDStore
    private let drafts: any ComposeDraftStore
    private let lockSettings: AppLockSettings
    /// 「この投稿を表示しない」を端末に保存しているとき（Firebase の構成）。インメモリの構成では Repository が持つので nil
    private let hiddenPosts: (any HiddenPostStore)?
    private let defaults: UserDefaults

    init(
        posts: any PostRepository,
        identity: any AnonymousIDStore,
        drafts: any ComposeDraftStore,
        lockSettings: AppLockSettings,
        hiddenPosts: (any HiddenPostStore)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.posts = posts
        self.identity = identity
        self.drafts = drafts
        self.lockSettings = lockSettings
        self.hiddenPosts = hiddenPosts
        self.defaults = defaults
    }

    /// すべて消す。終わると、次に開いたときは初回の画面（ようこそ）から始まる
    func eraseAll() async throws {
        try await posts.deleteAllMyData()
        // ID を消せなかったら、端末の中の設定も残して止める（もう一度ためせば、ID から消し直せる）
        try identity.deleteID()
        drafts.clear()
        lockSettings.reset()
        hiddenPosts?.clear()
        defaults.removeObject(forKey: OnboardingStatus.agreedVersionKey)
    }
}
