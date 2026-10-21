//
//  MaskingCandidate.swift
//  Kobosu
//
//  伏せ字の候補。身バレにつながりそうな文字列の範囲と種類。
//  検知は提案にとどめ、伏せるかどうかは本人が選ぶ。
//

import Foundation

nonisolated struct MaskingCandidate: Hashable, Sendable {
    enum Kind: String, CaseIterable, Hashable, Sendable {
        case personName
        case placeName
        case organizationName
        case phoneNumber
        case email
        case address
        case postalCode
        case link

        /// 候補の種類の表示名（伏せ字の提案画面で使う）
        var title: LocalizedStringResource {
            switch self {
            case .personName:
                "人の名前"
            case .placeName:
                "地名"
            case .organizationName:
                "学校や会社などの名前"
            case .phoneNumber:
                "電話番号"
            case .email:
                "メールアドレス"
            case .address:
                "住所"
            case .postalCode:
                "郵便番号"
            case .link:
                "URL"
            }
        }
    }

    let kind: Kind
    /// 本文の中の範囲
    let range: Range<String.Index>
    /// 候補の文字列
    let text: String
}
