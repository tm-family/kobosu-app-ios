//
//  SettingsTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct SettingsTests {
    /// テストごとに別の UserDefaults を使う
    private struct IsolatedDefaults {
        let suiteName = "SettingsTests.\(UUID().uuidString)"
        let defaults: UserDefaults

        init() throws {
            defaults = try #require(UserDefaults(suiteName: suiteName))
        }

        func clear() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private let now = Date(timeIntervalSince1970: 1_000_000)

    /// 自分の投稿・共感・通報と、他の人の投稿を置いた Repository
    private func makeRepository(identity: InMemoryAnonymousIDStore) async throws -> InMemoryPostRepository {
        let repository = InMemoryPostRepository(identity: identity, now: { [now] in now })
        repository.seed(Post(id: "others", body: "本文", category: .money, createdAt: now, stampCounts: [.sameHere: 1]))
        repository.seed(Post(id: "reported", body: "本文", category: .money, createdAt: now))
        _ = try await repository.submit(body: "自分の投稿", category: .partner)
        try await repository.sendStamp(.sameHere, to: "others")
        try await repository.report(postID: "reported", reason: .spam)
        try await repository.hide(postID: "reported")
        return repository
    }

    /// サーバーの自分の投稿・共感・通報を消し、他の人の投稿は残す
    @Test
    func deleteAllMyDataRemovesOnlyMine() async throws {
        let identity = InMemoryAnonymousIDStore(id: "me")
        let repository = try await makeRepository(identity: identity)
        try await repository.deleteAllMyData()

        #expect(try await repository.myPosts().isEmpty)
        let timeline = try await repository.timeline(category: nil)
        #expect(Set(timeline.map(\.id)) == ["others", "reported"])
        #expect(try await repository.sentStamps(for: "others").isEmpty)
        #expect(timeline.first { $0.id == "others" }?.sameHereCount == 1)
    }

    /// 自分の通報も取り下げる。しきい値に届いていた投稿は、自分の分が減るとまた出る
    @Test
    func deleteAllMyDataWithdrawsReports() async throws {
        let identity = InMemoryAnonymousIDStore(id: "me")
        let repository = try await makeRepository(identity: identity)
        for other in ["other-1", "other-2"] {
            identity.replaceID(with: other)
            try await repository.report(postID: "reported", reason: .spam)
        }
        identity.replaceID(with: "me")
        let before = try await repository.timeline(category: nil)
        #expect(!before.contains { $0.id == "reported" })

        try await repository.deleteAllMyData()
        let after = try await repository.timeline(category: nil)
        #expect(after.contains { $0.id == "reported" })
    }

    /// すべて消すと、下書き・前回のカテゴリ・アプリロックの設定・約束の同意・匿名 ID もなくなる
    @Test
    func eraseAllDeletesEverything() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let identity = InMemoryAnonymousIDStore(id: "me")
        let repository = try await makeRepository(identity: identity)
        let drafts = InMemoryComposeDraftStore(draft: ComposeDraft(body: "下書き", category: .money))
        let lastCategories = InMemoryLastCategoryStore(category: .partner)
        let lockSettings = AppLockSettings(defaults: isolated.defaults)
        lockSettings.isEnabled = false
        isolated.defaults.set(PromiseRule.currentVersion, forKey: OnboardingStatus.agreedVersionKey)
        let hiddenPosts = UserDefaultsHiddenPostStore(defaults: isolated.defaults, now: { [now] in now })
        hiddenPosts.hide("others")
        let eraser = DataEraser(
            posts: repository,
            identity: identity,
            drafts: drafts,
            lastCategories: lastCategories,
            lockSettings: lockSettings,
            hiddenPosts: hiddenPosts,
            defaults: isolated.defaults
        )

        try await eraser.eraseAll()
        #expect(try await repository.myPosts().isEmpty)
        #expect(drafts.load() == nil)
        #expect(lastCategories.load() == nil)
        #expect(lockSettings.isEnabled)
        #expect(isolated.defaults.object(forKey: OnboardingStatus.agreedVersionKey) == nil)
        #expect(hiddenPosts.hiddenPostIDs().isEmpty)
        #expect(identity.currentID() != "me")
    }

    /// 消し終わると .erased になり、もう一度呼んでも消し直さない
    @Test
    func eraseFinishesOnce() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let identity = InMemoryAnonymousIDStore(id: "me")
        let lockSettings = AppLockSettings(defaults: isolated.defaults)
        let eraser = DataEraser(
            posts: InMemoryPostRepository(identity: identity),
            identity: identity,
            drafts: InMemoryComposeDraftStore(),
            lastCategories: InMemoryLastCategoryStore(),
            lockSettings: lockSettings,
            defaults: isolated.defaults
        )
        let model = SettingsViewModel(authenticator: StubAppLockAuthenticator(), lockSettings: lockSettings, eraser: eraser)

        await model.eraseAll()
        #expect(model.eraseState == .erased)
        // 消したあとに作られた ID は、2 回目では消さない
        let newID = identity.currentID()
        await model.eraseAll()
        #expect(model.eraseState == .erased)
        #expect(identity.currentID() == newID)
    }

    /// サーバーを消せなかったら、端末の中も消さずに止める
    @Test
    func eraseStopsWhenServerFails() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let identity = InMemoryAnonymousIDStore(id: "me")
        let drafts = InMemoryComposeDraftStore(draft: ComposeDraft(body: "下書き", category: .money))
        let lastCategories = InMemoryLastCategoryStore(category: .partner)
        let lockSettings = AppLockSettings(defaults: isolated.defaults)
        lockSettings.isEnabled = false
        isolated.defaults.set(PromiseRule.currentVersion, forKey: OnboardingStatus.agreedVersionKey)
        let hiddenPosts = UserDefaultsHiddenPostStore(defaults: isolated.defaults, now: { [now] in now })
        hiddenPosts.hide("others")
        let eraser = DataEraser(
            posts: FailingDeleteRepository(),
            identity: identity,
            drafts: drafts,
            lastCategories: lastCategories,
            lockSettings: lockSettings,
            hiddenPosts: hiddenPosts,
            defaults: isolated.defaults
        )
        let model = SettingsViewModel(
            authenticator: StubAppLockAuthenticator(),
            lockSettings: AppLockSettings(defaults: isolated.defaults),
            eraser: eraser
        )

        await model.eraseAll()
        #expect(model.eraseState == .failed)
        #expect(drafts.load() != nil)
        #expect(lastCategories.load() == .partner)
        #expect(identity.currentID() == "me")
        #expect(!lockSettings.isEnabled)
        #expect(isolated.defaults.object(forKey: OnboardingStatus.agreedVersionKey) != nil)
        #expect(hiddenPosts.hiddenPostIDs() == ["others"])
    }

    /// オンにするときは確かめ、確かめられなければオフのまま。オフにするときは確かめない
    @Test
    func lockToggleAuthenticatesOnlyWhenTurningOn() async throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)
        settings.isEnabled = false
        let authenticator = StubAppLockAuthenticator(succeeds: false)
        let eraser = DataEraser(
            posts: InMemoryPostRepository(),
            identity: InMemoryAnonymousIDStore(),
            drafts: InMemoryComposeDraftStore(),
            lastCategories: InMemoryLastCategoryStore(),
            lockSettings: settings,
            defaults: isolated.defaults
        )
        let model = SettingsViewModel(authenticator: authenticator, lockSettings: settings, eraser: eraser)
        #expect(!model.isLockOn)

        await model.setLock(true, reason: "理由")
        #expect(!model.isLockOn)
        #expect(!settings.isEnabled)

        authenticator.succeeds = true
        await model.setLock(true, reason: "理由")
        #expect(model.isLockOn)
        #expect(settings.isEnabled)
        #expect(authenticator.authenticateCount == 2)

        await model.setLock(false, reason: "理由")
        #expect(!model.isLockOn)
        #expect(!settings.isEnabled)
        #expect(authenticator.authenticateCount == 2)
    }

    /// パスコードの無い端末では、ロックはオフのまま
    @Test
    func lockIsOffWithoutPasscode() throws {
        let isolated = try IsolatedDefaults()
        defer { isolated.clear() }
        let settings = AppLockSettings(defaults: isolated.defaults)
        let eraser = DataEraser(
            posts: InMemoryPostRepository(),
            identity: InMemoryAnonymousIDStore(),
            drafts: InMemoryComposeDraftStore(),
            lastCategories: InMemoryLastCategoryStore(),
            lockSettings: settings,
            defaults: isolated.defaults
        )
        let model = SettingsViewModel(authenticator: StubAppLockAuthenticator(method: nil), lockSettings: settings, eraser: eraser)
        #expect(model.lockMethod == nil)
        #expect(!model.isLockOn)
    }

    /// 同梱したライセンス文を表示できる
    @Test
    func licenseTextIsBundled() {
        #expect(LicenseView.fontLicense.contains("SIL OPEN FONT LICENSE"))
    }

    /// 運営への連絡先と規約の URL がそろっていて、どれも https で開ける（審査ガイドライン 1.2）
    @Test
    func supportLinksAreHTTPS() throws {
        let urls = [SupportInfo.contactURL, SupportInfo.termsURL, SupportInfo.privacyPolicyURL]
        for url in urls {
            #expect(try #require(url).scheme == "https")
        }
    }
}

/// 消すのがいつも失敗する Repository（既定の deleteAllMyData を通る）
private final class FailingDeleteRepository: PostRepository {
    struct Failure: Error {}

    func timeline(category: PostCategory?) async throws -> [Post] { [] }
    func submit(body: String, category: PostCategory) async throws -> Post { throw Failure() }
    func myPosts() async throws -> [Post] {
        [Post(id: "mine", body: "本文", category: .money, createdAt: Date())]
    }
    func delete(postID: Post.ID) async throws { throw Failure() }
    func sendStamp(_ stamp: EmpathyStamp, to postID: Post.ID) async throws {}
    func sentStamps(for postID: Post.ID) async throws -> Set<EmpathyStamp> { [] }
}
