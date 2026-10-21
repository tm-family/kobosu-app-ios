//
//  AppDependencies.swift
//  Kobosu
//
//  アプリ全体で使う Repository などをまとめて作り、画面に渡す。
//  いまはインメモリ実装で動かし、Firebase の実装ができたら local() の中身を差し替える。
//

import Foundation

final class AppDependencies {
    let identity: any AnonymousIDStore
    let posts: any PostRepository
    let reports: any ReportRepository
    let drafts: any ComposeDraftStore

    init(
        identity: any AnonymousIDStore,
        posts: any PostRepository,
        reports: any ReportRepository,
        drafts: any ComposeDraftStore
    ) {
        self.identity = identity
        self.posts = posts
        self.reports = reports
        self.drafts = drafts
    }

    /// ふだんの起動。匿名 ID は Keychain に、下書きは UserDefaults に保存する
    static func local() -> AppDependencies {
        let identity = KeychainAnonymousIDStore()
        let repository = InMemoryPostRepository(identity: identity)
        return AppDependencies(
            identity: identity,
            posts: repository,
            reports: repository,
            drafts: UserDefaultsComposeDraftStore()
        )
    }

    /// 撮影モード・Preview。デモデータをメモリ上にだけ置く（実データと混ぜない）
    static func demo() -> AppDependencies {
        let identity = InMemoryAnonymousIDStore()
        let repository = InMemoryPostRepository.preview(identity: identity)
        return AppDependencies(
            identity: identity,
            posts: repository,
            reports: repository,
            drafts: InMemoryComposeDraftStore()
        )
    }
}
