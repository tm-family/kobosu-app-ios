//
//  CategorySuggestion.swift
//  Kobosu
//
//  投稿画面で先に選んでおくカテゴリ（Discussion #76 の Q3）。
//  本文から推定（CategoryEstimator）→ 推定できなければ前回のカテゴリ → どちらも無ければ未分類、の順に選ぶ。
//  本人が選んだあとは、推定で上書きしない（ComposeViewModel が chosen のときは呼ばない）。
//  どうやって選ばれたかで、画面の文言（「自動で選びました」「前回と同じ」など）を変える。
//

import Foundation

/// カテゴリがどうやって選ばれたか
nonisolated enum CategorySource: Equatable, Sendable {
    /// 本文から推定した
    case estimated
    /// 推定できず、前回の投稿のカテゴリにした
    case previous
    /// 本人が選んだ
    case chosen
    /// 推定できず、前回のカテゴリも無い（未分類のまま）
    case uncategorized
}

/// 先に選んでおくカテゴリと、その選ばれ方
nonisolated struct CategorySuggestion: Equatable, Sendable {
    let category: PostCategory
    let source: CategorySource

    /// 本文と前回のカテゴリから選ぶ。前回のカテゴリが未分類なら無いものとして扱う
    static func suggest(for body: String, lastCategory: PostCategory?) -> CategorySuggestion {
        if let estimated = CategoryEstimator.estimate(body) {
            return CategorySuggestion(category: estimated, source: .estimated)
        }
        if let lastCategory, lastCategory != .uncategorized {
            return CategorySuggestion(category: lastCategory, source: .previous)
        }
        return CategorySuggestion(category: .uncategorized, source: .uncategorized)
    }
}
