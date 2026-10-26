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
}
