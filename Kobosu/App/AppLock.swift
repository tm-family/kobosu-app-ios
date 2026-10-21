//
//  AppLock.swift
//  Kobosu
//
//  アプリロック。家族と同じ端末や画面を見られる場面を想定し、開くときに Face ID（使えなければパスコード）で確かめる。
//  認証は LocalAuthentication のプロトコルの裏に置き、テスト・Preview・撮影モードでは差し替える。
//  オンかオフかは端末内（UserDefaults）にだけ保存する。初期値はオン。
//

import Foundation
import LocalAuthentication

/// この端末で使えるロックの方法
nonisolated enum AppLockMethod: Equatable, Sendable {
    case faceID
    case touchID
    case opticID
    /// 生体認証が無い・登録していない端末。パスコードで確かめる
    case passcode

    /// トグルの見出し
    var title: LocalizedStringResource {
        switch self {
        case .faceID:
            "Face ID でロック"
        case .touchID:
            "Touch ID でロック"
        case .opticID:
            "Optic ID でロック"
        case .passcode:
            "パスコードでロック"
        }
    }

    var systemImage: String {
        switch self {
        case .faceID:
            "faceid"
        case .touchID:
            "touchid"
        case .opticID:
            "opticid"
        case .passcode:
            "lock"
        }
    }
}

protocol AppLockAuthenticating: AnyObject {
    /// この端末で使えるロックの方法。パスコードも設定していない端末では nil（ロックを使えない）
    func availableMethod() -> AppLockMethod?
    /// 本人か確かめる。確かめられたら true。取り消し・失敗・使えないときは false
    func authenticate(reason: String) async -> Bool
}

/// ふだんの起動。Face ID・Touch ID・Optic ID が使えなければパスコードで確かめる
final class LocalAuthenticationAppLock: AppLockAuthenticating {
    func availableMethod() -> AppLockMethod? {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return nil
        }
        // biometryType は canEvaluatePolicy の後で決まる。生体認証が使えないときは .none になる
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .passcode
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        default:
            return .passcode
        }
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// テスト・Preview・撮影モード用。決めた結果を返す
final class StubAppLockAuthenticator: AppLockAuthenticating {
    var method: AppLockMethod?
    var succeeds: Bool
    /// authenticate が呼ばれた回数
    private(set) var authenticateCount = 0

    init(method: AppLockMethod? = .faceID, succeeds: Bool = true) {
        self.method = method
        self.succeeds = succeeds
    }

    func availableMethod() -> AppLockMethod? {
        method
    }

    func authenticate(reason: String) async -> Bool {
        authenticateCount += 1
        return method != nil && succeeds
    }
}

/// アプリロックをオンにしているか。端末内（UserDefaults）にだけ保存する
final class AppLockSettings {
    /// オンかオフかを保存するキー
    nonisolated static let enabledKey = "appLock.isEnabled"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// まだ選んでいなければオン（初期値）
    var isEnabled: Bool {
        get {
            defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: Self.enabledKey)
        }
    }

    /// 選んだ値を消して初期値に戻す（「すべてのデータを削除」）
    func reset() {
        defaults.removeObject(forKey: Self.enabledKey)
    }
}
