//
//  PostCategory.swift
//  Kobosu
//
//  投稿のカテゴリ。タイムラインの絞り込みでも case の順に並べる。
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
    /// 自分の親との関わり、過干渉、距離のとり方
    case ownParents = "own_parents"
    /// きょうだい・親戚とのつきあい、冠婚葬祭、お盆やお正月の集まり
    case relatives
    /// 親や義父母の介護、通院の付き添い、介護の分担
    case caregiving
    /// 仕事と家庭の両立、時間が足りない
    case workAndFamily = "work_and_family"
    /// どれにも当てはまらないもの
    case other

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
        case .ownParents:
            "実の親"
        case .relatives:
            "きょうだい・親戚"
        case .caregiving:
            "介護"
        case .workAndFamily:
            "仕事と家庭"
        case .other:
            "その他"
        }
    }
}
