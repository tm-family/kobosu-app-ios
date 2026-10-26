//
//  PostCategory.swift
//  Kobosu
//
//  投稿のカテゴリ。タイムラインの絞り込みでも case の順に並べる（未分類は絞り込みに出さない）。
//  rawValue は保存・通信に使う識別子なので、表示名を変えても書き換えない（表示名は Localizable.xcstrings）。
//

import Foundation

nonisolated enum PostCategory: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    /// 義父母との関わり、同居、帰省、口出し
    case inLaws = "in_laws"
    /// 夫・妻とのすれ違い、言い方へのモヤモヤ
    case partner
    /// 寝かしつけ、子どもとのぶつかり、園や学校のこと
    case parenting
    /// 分担の偏り、「手伝う」という感覚
    case housework
    /// 家計や出費、お金の価値観の違い
    case money
    /// どれにも当てはまらないもの
    case other
    /// カテゴリを付けていないもの。タイムラインでは「すべて」にだけ出る
    case uncategorized

    /// タイムラインの絞り込みに出すカテゴリ（未分類を除く 6 つ）
    static let filterable: [PostCategory] = allCases.filter { $0 != .uncategorized }

    var id: Self { self }

    /// 表示名
    var title: LocalizedStringResource {
        switch self {
        case .inLaws:
            "義理の親"
        case .partner:
            "パートナー"
        case .parenting:
            "子育て"
        case .housework:
            "家事分担"
        case .money:
            "お金"
        case .other:
            "その他"
        case .uncategorized:
            "未分類"
        }
    }

    /// 投稿のカードに出すタグ。未分類のときは出さない
    var tagTitle: LocalizedStringResource? {
        self == .uncategorized ? nil : title
    }
}
