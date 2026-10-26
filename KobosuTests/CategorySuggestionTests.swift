//
//  CategorySuggestionTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct CategorySuggestionTests {
    /// 推定できれば、前回のカテゴリより推定を選ぶ
    @Test
    func prefersEstimate() {
        let suggestion = CategorySuggestion.suggest(for: "保育園のお迎えに間に合わなかった。", lastCategory: .money)
        #expect(suggestion == CategorySuggestion(category: .parenting, source: .estimated))
    }

    /// 推定できなければ前回のカテゴリ
    @Test
    func fallsBackToLastCategory() {
        let suggestion = CategorySuggestion.suggest(for: "今日はなんだか疲れた。", lastCategory: .money)
        #expect(suggestion == CategorySuggestion(category: .money, source: .previous))
    }

    /// 推定できず前回のカテゴリも無い（未分類も無いものとして扱う）ときは未分類
    @Test(arguments: [nil, PostCategory.uncategorized])
    func fallsBackToUncategorized(lastCategory: PostCategory?) {
        let suggestion = CategorySuggestion.suggest(for: "今日はなんだか疲れた。", lastCategory: lastCategory)
        #expect(suggestion == CategorySuggestion(category: .uncategorized, source: .uncategorized))
    }

    /// 本文が空なら推定せず、前回のカテゴリか未分類
    @Test
    func emptyBodyUsesLastCategory() {
        #expect(CategorySuggestion.suggest(for: "", lastCategory: .inLaws).source == .previous)
        #expect(CategorySuggestion.suggest(for: "", lastCategory: nil).source == .uncategorized)
    }

    /// 行の文言: 推定のときだけ「自動で選びました」。前回のカテゴリのときは別の文言にする（Q3）
    @Test
    func statusTextDependsOnSource() {
        func japanese(_ source: CategorySource) -> String {
            var resource = source.statusText
            resource.locale = Locale(identifier: "ja")
            return String(localized: resource)
        }
        #expect(japanese(.estimated) == "自動で選びました")
        #expect(japanese(.previous) == "前回と同じ")
        let texts = [CategorySource.estimated, .previous, .chosen, .uncategorized].map(japanese)
        #expect(Set(texts).count == texts.count)
    }

    /// 行の文言は String Catalog に ja / en の両方がある
    @Test(arguments: [CategorySource.estimated, .previous, .chosen, .uncategorized])
    func statusTextIsLocalized(source: CategorySource) {
        var japanese = source.statusText
        japanese.locale = Locale(identifier: "ja")
        var english = source.statusText
        english.locale = Locale(identifier: "en")
        #expect(String(localized: japanese) != String(localized: english))
    }
}
