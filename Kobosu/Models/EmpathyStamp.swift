//
//  EmpathyStamp.swift
//  Kobosu
//
//  投稿に返せる共感スタンプ。返せるのは共感だけなので、コメントの代わりにこの 4 種だけを置く。
//  rawValue は保存・通信に使う識別子なので、表示名を変えても書き換えない（表示名は Localizable.xcstrings）。
//

import Foundation

/// CodingKeyRepresentable にして、スタンプごとの人数（[EmpathyStamp: Int]）を `{"same_here": 41}` の形で保存する
nonisolated enum EmpathyStamp: String, CaseIterable, Codable, CodingKeyRepresentable, Hashable, Identifiable, Sendable {
    case understand
    case hardDay = "hard_day"
    /// 強調する数字はこのスタンプの人数だけにする
    case sameHere = "same_here"
    case wellDone = "well_done"

    var id: Self { self }

    /// 表示名
    var title: LocalizedStringResource {
        switch self {
        case .understand:
            "わかる"
        case .hardDay:
            "しんどいね"
        case .sameHere:
            "うちも同じ"
        case .wellDone:
            "おつかれさま"
        }
    }
}
