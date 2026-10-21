//
//  ReportReason.swift
//  Kobosu
//
//  通報の理由。通報シートでは 1 つだけ選ぶ（デザイン案 Issue #3 の「通報」）。
//  rawValue は保存・通信に使う識別子なので、表示名を変えても書き換えない（表示名は Localizable.xcstrings）。
//

import Foundation

nonisolated enum ReportReason: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    /// 人名・住所・勤務先など、特定の人が分かる情報が書かれている
    case identifiableInformation = "identifiable_information"
    /// 特定の誰かを強く攻撃している
    case harassment
    /// 自傷や暴力など、危険を感じる内容がある
    case dangerous
    /// 宣伝や、家庭の悩みと関係のない投稿
    case spam
    /// どれにも当てはまらないもの
    case other

    var id: Self { self }

    /// 表示名
    var title: LocalizedStringResource {
        switch self {
        case .identifiableInformation:
            "特定の人が分かる情報がある"
        case .harassment:
            "誰かを強く攻撃している"
        case .dangerous:
            "危険を感じる内容がある"
        case .spam:
            "宣伝や関係のない投稿"
        case .other:
            "そのほか"
        }
    }
}
