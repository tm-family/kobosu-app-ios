//
//  AppLockSetupViewModel.swift
//  Kobosu
//
//  初回のアプリロックの設定（デザイン案 07）。トグルの初期値はオン。
//  オンのまま「設定して次へ」を押したら一度本人か確かめ（Face ID の許可もここで出る）、確かめられたらオンで保存する。
//  「あとで設定する」はオフで保存する（設定画面からいつでもオンにできる）。
//

import Foundation
import Observation

@Observable
final class AppLockSetupViewModel {
    enum State: Equatable {
        case editing
        case authenticating
        /// 確かめられなかった（取り消した・失敗した）
        case failed
    }

    var isLockOn = true
    private(set) var state = State.editing
    /// この端末で使えるロックの方法。nil ならロックを使えない（パスコードを設定していない）
    let method: AppLockMethod?

    private let authenticator: any AppLockAuthenticating
    private let settings: AppLockSettings

    init(authenticator: any AppLockAuthenticating, settings: AppLockSettings) {
        self.authenticator = authenticator
        self.settings = settings
        method = authenticator.availableMethod()
        if method == nil {
            isLockOn = false
        }
    }

    var canUseLock: Bool {
        method != nil
    }

    /// 「設定して次へ」。保存できたら true を返す（次の画面へ進む）
    func confirm(reason: String) async -> Bool {
        guard state != .authenticating else {
            return false
        }
        guard isLockOn, canUseLock else {
            settings.isEnabled = false
            return true
        }
        state = .authenticating
        let authenticated = await authenticator.authenticate(reason: reason)
        guard authenticated else {
            state = .failed
            return false
        }
        settings.isEnabled = true
        state = .editing
        return true
    }

    /// 「あとで設定する」。オフで保存する
    func skip() {
        settings.isEnabled = false
    }
}
