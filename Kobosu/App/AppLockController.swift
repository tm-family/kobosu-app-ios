//
//  AppLockController.swift
//  Kobosu
//
//  アプリロックの状態。アプリロックがオンなら、2 回目以降の起動とアプリ切り替え（バックグラウンドに入る）のたびにロックする。
//  前に出てきたら一度だけ自動で本人か確かめ、取り消したら「開く」のボタンを押すまで待つ。
//  Face ID の確認中やコントロールセンターを開いたとき（inactive）はロックしない（バックグラウンドに入ったときだけ）。
//

import Foundation
import Observation

@Observable
final class AppLockController {
    /// ロック中か。ロック中は中身を一切見せない
    private(set) var isLocked: Bool
    /// 確かめている途中か
    private(set) var isAuthenticating = false
    /// 前に出てきたときに、自動で確かめるか（取り消した後は、もう一度出てくるまで自動では確かめない）
    private var shouldAuthenticateAutomatically: Bool

    private let authenticator: any AppLockAuthenticating
    private let settings: AppLockSettings
    /// ロックを使う状態か（初回の画面を終えていて、撮影モードでない）。ロックの設定とは別に、呼ぶたびに確かめる
    private let isLockAvailable: () -> Bool

    init(authenticator: any AppLockAuthenticating, settings: AppLockSettings, isLockAvailable: @escaping () -> Bool) {
        self.authenticator = authenticator
        self.settings = settings
        self.isLockAvailable = isLockAvailable
        let locks = settings.isEnabled && isLockAvailable() && authenticator.availableMethod() != nil
        isLocked = locks
        shouldAuthenticateAutomatically = locks
    }

    /// この端末で使えるロックの方法（ボタンの見出し）
    var method: AppLockMethod {
        authenticator.availableMethod() ?? .passcode
    }

    /// バックグラウンドに入った。アプリロックがオンならロックする
    func didEnterBackground() {
        guard settings.isEnabled, isLockAvailable(), authenticator.availableMethod() != nil else {
            return
        }
        isLocked = true
        shouldAuthenticateAutomatically = true
    }

    /// 前に出てきた。ロック中なら一度だけ自動で確かめる
    func didBecomeActive(reason: String) async {
        guard isLocked, shouldAuthenticateAutomatically else {
            return
        }
        shouldAuthenticateAutomatically = false
        await unlock(reason: reason)
    }

    /// 本人か確かめて、確かめられたらロックを外す
    func unlock(reason: String) async {
        guard isLocked, !isAuthenticating else {
            return
        }
        // アプリロックをオフにしていた・ロックを使えなくなった（パスコードを外した）ときは、そのまま開く
        guard settings.isEnabled, authenticator.availableMethod() != nil else {
            isLocked = false
            return
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await authenticator.authenticate(reason: reason) {
            isLocked = false
        }
    }
}
