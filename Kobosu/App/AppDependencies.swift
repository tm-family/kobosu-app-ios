//
//  AppDependencies.swift
//  Kobosu
//
//  アプリ全体で使う Repository などをまとめて作り、画面に渡す。
//  Firebase を設定したときは firebase()、GoogleService-Info.plist が無いときは local()（インメモリ）で動かす。
//

import Foundation

final class AppDependencies {
    let identity: any AnonymousIDStore
    let posts: any PostRepository
    let reports: any ReportRepository
    let drafts: any ComposeDraftStore
    let appLock: any AppLockAuthenticating
    let lockSettings: AppLockSettings

    init(
        identity: any AnonymousIDStore,
        posts: any PostRepository,
        reports: any ReportRepository,
        drafts: any ComposeDraftStore,
        appLock: any AppLockAuthenticating,
        lockSettings: AppLockSettings
    ) {
        self.identity = identity
        self.posts = posts
        self.reports = reports
        self.drafts = drafts
        self.appLock = appLock
        self.lockSettings = lockSettings
    }

    /// 「すべてのデータを削除」
    func makeEraser() -> DataEraser {
        DataEraser(posts: posts, identity: identity, drafts: drafts, lockSettings: lockSettings)
    }

    /// ふだんの起動。匿名 ID は Keychain に、下書きとアプリロックの設定は UserDefaults に保存する
    static func local() -> AppDependencies {
        let identity = KeychainAnonymousIDStore()
        let repository = InMemoryPostRepository(identity: identity)
        return AppDependencies(
            identity: identity,
            posts: repository,
            reports: repository,
            drafts: UserDefaultsComposeDraftStore(),
            appLock: LocalAuthenticationAppLock(),
            lockSettings: AppLockSettings()
        )
    }

    /// Firebase を設定したとき。投稿とタイムラインは Firestore で読み書きし、匿名認証の uid を Keychain の匿名 ID として控える。
    /// 通報・「この投稿を表示しない」は、タスク 21 までは「まだ使えない」を返す
    static func firebase() -> AppDependencies {
        let identity = KeychainAnonymousIDStore()
        return AppDependencies(
            identity: identity,
            posts: FirestorePostRepository(identity: identity),
            reports: FirestoreReportRepository(),
            drafts: UserDefaultsComposeDraftStore(),
            appLock: LocalAuthenticationAppLock(),
            lockSettings: AppLockSettings()
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
            drafts: InMemoryComposeDraftStore(),
            appLock: StubAppLockAuthenticator(),
            // 撮影モードの設定は、ふだんの設定と混ぜない
            lockSettings: AppLockSettings(defaults: UserDefaults(suiteName: "screenshot-demo") ?? .standard)
        )
    }
}
