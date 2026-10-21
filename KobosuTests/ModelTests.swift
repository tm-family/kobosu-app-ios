//
//  ModelTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct ModelTests {
    /// 保存・通信に使う識別子。変えると保存済みのデータが読めなくなるので、変わったら気づけるようにする
    @Test
    func categoryRawValuesAreStable() {
        #expect(PostCategory.allCases.map(\.rawValue) == [
            "in_laws", "partner", "parenting", "housework", "money",
            "own_parents", "relatives", "caregiving", "work_and_family", "other"
        ])
    }

    /// 絞り込みの先頭は「義理の親」、末尾は「その他」にする
    @Test
    func categoryOrderStartsWithInLawsAndEndsWithOther() {
        #expect(PostCategory.allCases.first == .inLaws)
        #expect(PostCategory.allCases.last == .other)
    }

    @Test
    func stampRawValuesAreStable() {
        #expect(EmpathyStamp.allCases.map(\.rawValue) == ["understand", "hard_day", "same_here", "well_done"])
    }

    @Test
    func reportReasonRawValuesAreStable() {
        #expect(ReportReason.allCases.map(\.rawValue) == [
            "identifiable_information", "harassment", "dangerous", "spam", "other"
        ])
    }

    /// 表示名は String Catalog に ja / en の両方がある
    @Test(arguments: Self.allTitles)
    func titleIsLocalized(title: LocalizedStringResource) {
        let japanese = Self.localized(title, language: "ja")
        let english = Self.localized(title, language: "en")
        #expect(!japanese.isEmpty)
        #expect(!english.isEmpty)
        #expect(japanese != english, "en の訳が Localizable.xcstrings に無い: \(japanese)")
    }

    @Test
    func titlesAreUniqueWithinEachKind() {
        let categoryTitles = PostCategory.allCases.map { Self.localized($0.title, language: "ja") }
        let stampTitles = EmpathyStamp.allCases.map { Self.localized($0.title, language: "ja") }
        let reasonTitles = ReportReason.allCases.map { Self.localized($0.title, language: "ja") }
        #expect(Set(categoryTitles).count == categoryTitles.count)
        #expect(Set(stampTitles).count == stampTitles.count)
        #expect(Set(reasonTitles).count == reasonTitles.count)
    }

    @Test
    func postExpiresTwentyFourHoursAfterCreationByDefault() {
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let post = Post(id: "post", body: "今日も黙って洗い物をした。", category: .housework, createdAt: createdAt)
        #expect(post.expireAt == createdAt.addingTimeInterval(24 * 60 * 60))
    }

    @Test
    func postKeepsGivenExpireAt() {
        let createdAt = Date(timeIntervalSince1970: 1_000_000)
        let expireAt = createdAt.addingTimeInterval(60)
        let post = Post(id: "post", body: "本文", category: .other, createdAt: createdAt, expireAt: expireAt)
        #expect(post.expireAt == expireAt)
    }

    @Test
    func stampCountDefaultsToZero() {
        let post = Post(
            id: "post",
            body: "本文",
            category: .inLaws,
            createdAt: .now,
            stampCounts: [.sameHere: 41, .understand: 24]
        )
        #expect(post.sameHereCount == 41)
        #expect(post.count(of: .understand) == 24)
        #expect(post.count(of: .hardDay) == 0)
    }

    @Test
    func postLimitsMatchSpec() {
        #expect(Post.maxBodyLength == 400)
        #expect(Post.lifetime == 24 * 60 * 60)
    }

    /// スタンプの人数は、項目ごとに加算できるよう JSON のオブジェクト（{"same_here": 41}）で保存する
    @Test
    func stampCountsEncodeAsObject() throws {
        let post = Post(
            id: "post",
            body: "本文",
            category: .inLaws,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            stampCounts: [.sameHere: 41]
        )
        let data = try JSONEncoder().encode(post)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let counts = try #require(object["stampCounts"] as? [String: Int])
        #expect(counts == ["same_here": 41])
    }

    @Test
    func postRoundTripsThroughJSON() throws {
        let post = Post(
            id: "post",
            body: "本文",
            category: .workAndFamily,
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            stampCounts: [.wellDone: 3]
        )
        let data = try JSONEncoder().encode(post)
        #expect(try JSONDecoder().decode(Post.self, from: data) == post)
    }

    nonisolated private static let allTitles: [LocalizedStringResource] =
        PostCategory.allCases.map(\.title) + EmpathyStamp.allCases.map(\.title) + ReportReason.allCases.map(\.title)

    private static func localized(_ resource: LocalizedStringResource, language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }
}
