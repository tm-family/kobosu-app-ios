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
    /// 約束に同意した版などを置く UserDefaults（「すべてのデータを削除」で消す）
    let settingsDefaults: UserDefaults
    /// 「この投稿を表示しない」を端末に保存しているとき（Firebase の構成）
    let hiddenPosts: (any HiddenPostStore)?

    init(
        identity: any AnonymousIDStore,
        posts: any PostRepository,
        reports: any ReportRepository,
        drafts: any ComposeDraftStore,
        appLock: any AppLockAuthenticating,
        lockSettings: AppLockSettings,
        settingsDefaults: UserDefaults = .standard,
        hiddenPosts: (any HiddenPostStore)? = nil
    ) {
        self.identity = identity
        self.posts = posts
        self.reports = reports
        self.drafts = drafts
        self.appLock = appLock
        self.lockSettings = lockSettings
        self.settingsDefaults = settingsDefaults
        self.hiddenPosts = hiddenPosts
    }

    /// 「すべてのデータを削除」
    func makeEraser() -> DataEraser {
        DataEraser(
            posts: posts,
            identity: identity,
            drafts: drafts,
            lockSettings: lockSettings,
            hiddenPosts: hiddenPosts,
            defaults: settingsDefaults
        )
    }

    /// ふだんの起動。匿名 ID は Keychain に、下書きとアプリロックの設定は UserDefaults に保存する。
    /// seedsPosts は UI テスト用で、他の人の投稿（Preview と同じデモデータ）を置いて開く
    static func local(seedsPosts: Bool = false) -> AppDependencies {
        let identity = KeychainAnonymousIDStore()
        let repository = seedsPosts
            ? InMemoryPostRepository.preview(identity: identity)
            : InMemoryPostRepository(identity: identity)
        return AppDependencies(
            identity: identity,
            posts: repository,
            reports: repository,
            drafts: UserDefaultsComposeDraftStore(),
            appLock: LocalAuthenticationAppLock(),
            lockSettings: AppLockSettings()
        )
    }

    /// Firebase を設定したとき。投稿・タイムライン・通報は Firestore で読み書きし、匿名認証の uid を Keychain の匿名 ID として控える。
    /// 「この投稿を表示しない」は端末の中にだけ保存する
    static func firebase() -> AppDependencies {
        let identity = KeychainAnonymousIDStore()
        // サインインを 1 つずつ行うため、投稿と通報で同じものを使う
        let auth = FirebaseAnonymousAuth()
        let hiddenPosts = UserDefaultsHiddenPostStore()
        return AppDependencies(
            identity: identity,
            posts: FirestorePostRepository(identity: identity, auth: auth, hiddenPosts: hiddenPosts),
            reports: FirestoreReportRepository(identity: identity, auth: auth, hiddenPosts: hiddenPosts),
            drafts: UserDefaultsComposeDraftStore(),
            appLock: LocalAuthenticationAppLock(),
            lockSettings: AppLockSettings(),
            hiddenPosts: hiddenPosts
        )
    }

    /// 撮影モード・Preview。デモデータをメモリ上にだけ置く（実データと混ぜない）。
    /// ノートに出す自分の投稿と、投稿の画面に出す書きかけの下書きも用意する
    static func demo() -> AppDependencies {
        let identity = InMemoryAnonymousIDStore(id: ScreenshotDemo.myID)
        let repository = InMemoryPostRepository.preview(identity: identity)
        repository.seed(ScreenshotDemo.myPost(), authorID: ScreenshotDemo.myID)
        // 撮影モードの設定は、ふだんの設定と混ぜない（「すべてのデータを削除」を押しても、ふだんの同意の記録は消さない）
        let defaults = UserDefaults(suiteName: "screenshot-demo") ?? .standard
        return AppDependencies(
            identity: identity,
            posts: repository,
            reports: repository,
            drafts: InMemoryComposeDraftStore(draft: ScreenshotDemo.draft()),
            appLock: StubAppLockAuthenticator(),
            lockSettings: AppLockSettings(defaults: defaults),
            settingsDefaults: defaults
        )
    }
}
