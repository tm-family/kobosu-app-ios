//
//  SupportInfo.swift
//  Kobosu
//
//  運営への連絡先と、利用規約・プライバシーポリシーの場所。App Store 審査ガイドライン 1.2（ユーザー生成コンテンツ）で連絡先の掲載が求められる。
//  値は人間が用意する（まだ決まっていないものは nil にし、設定画面に出さない）。
//

import Foundation

nonisolated enum SupportInfo {
    /// 運営への連絡先のメールアドレス
    static let contactEmail: String? = nil
    /// 利用規約のページ
    static let termsURL: URL? = nil
    /// プライバシーポリシーのページ
    static let privacyPolicyURL: URL? = nil

    /// 連絡先のメールを開く URL
    static var contactURL: URL? {
        contactEmail.flatMap { URL(string: "mailto:\($0)") }
    }
}
