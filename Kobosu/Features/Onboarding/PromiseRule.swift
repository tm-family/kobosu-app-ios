//
//  PromiseRule.swift
//  Kobosu
//
//  やさしさの約束（場のルール 4 つ）。デザイン案 06 の文言。
//

import Foundation

nonisolated enum PromiseRule: Int, CaseIterable, Identifiable, Sendable {
    case writeYourFeelings = 1
    case keepOthersAnonymous
    case empathyOverAdvice
    case reachOutForHelp

    /// ルールの版。ルールを変えたら上げると、同意した人にもう一度見せる
    static let currentVersion = 1

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .writeYourFeelings:
            "自分の気持ちを主語にして書く"
        case .keepOthersAnonymous:
            "相手が特定できることは書かない"
        case .empathyOverAdvice:
            "アドバイスより、共感を返す"
        case .reachOutForHelp:
            "つらいときは、窓口も頼っていい"
        }
    }
}
