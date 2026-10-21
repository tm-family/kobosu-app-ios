//
//  SupportInfo.swift
//  Kobosu
//
//  運営への連絡先と、利用規約・プライバシーポリシーの場所。App Store 審査ガイドライン 1.2（ユーザー生成コンテンツ）で連絡先の掲載が求められる。
//  値は人間が用意したもの（PR #40 の ask への回答）。nil にした項目は設定画面に出さない。
//

import Foundation

nonisolated enum SupportInfo {
    /// 運営への連絡先（問い合わせフォーム）
    static let contactURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSc4DiUAcjKlrchuefXxehD-BgCEhGVomX6NOwtijWiE0yJAlQ/viewform?usp=dialog")
    /// 利用規約のページ
    static let termsURL = URL(string: "https://shilokuma.jp/terms/kobosu/")
    /// プライバシーポリシーのページ
    static let privacyPolicyURL = URL(string: "https://shilokuma.jp/privacy/kobosu/")
}
