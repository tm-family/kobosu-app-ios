//
//  SettingsViewModel.swift
//  Kobosu
//
//  設定画面のアプリロックの切り替えと、「すべてのデータを削除」。
//  アプリロックをオンにするときは一度本人か確かめる（確かめられなければオフのまま）。オフにするときは確かめない（開けている人が使っているため）。
//

import Foundation
import Observation

@Observable
final class SettingsViewModel {
    enum EraseState: Equatable {
        case idle
        case erasing
        /// 消せなかった（サーバーに届かなかったなど）。端末の中は消していないので、もう一度ためせる
        case failed
        case erased
    }

    private(set) var isLockOn: Bool
    private(set) var isChangingLock = false
    private(set) var eraseState = EraseState.idle
    /// この端末で使えるロックの方法。nil ならロックを使えない
    let lockMethod: AppLockMethod?

    private let authenticator: any AppLockAuthenticating
    private let lockSettings: AppLockSettings
    private let eraser: DataEraser

    init(authenticator: any AppLockAuthenticating, lockSettings: AppLockSettings, eraser: DataEraser) {
        self.authenticator = authenticator
        self.lockSettings = lockSettings
        self.eraser = eraser
        lockMethod = authenticator.availableMethod()
        isLockOn = lockSettings.isEnabled && lockMethod != nil
    }

    /// アプリロックを切り替える。オンにするときは確かめてから保存する
    func setLock(_ isOn: Bool, reason: String) async {
        guard !isChangingLock, isOn != isLockOn else {
            return
        }
        guard isOn else {
            lockSettings.isEnabled = false
            isLockOn = false
            return
        }
        guard lockMethod != nil else {
            return
        }
        isChangingLock = true
        defer { isChangingLock = false }
        if await authenticator.authenticate(reason: reason) {
            lockSettings.isEnabled = true
            isLockOn = true
        }
    }

    /// すべてのデータを削除する
    func eraseAll() async {
        guard eraseState != .erasing, eraseState != .erased else {
            return
        }
        eraseState = .erasing
        do {
            try await eraser.eraseAll()
            eraseState = .erased
        } catch {
            eraseState = .failed
        }
    }
}
