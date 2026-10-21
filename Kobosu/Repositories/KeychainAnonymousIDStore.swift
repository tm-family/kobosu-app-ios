//
//  KeychainAnonymousIDStore.swift
//  Kobosu
//
//  匿名 ID を Keychain に保存する。Keychain の項目はアプリを削除しても端末に残るため、
//  再インストールしても同じ ID を使える（Discussion #5 Q4）。
//  ほかの端末へ移さない（iCloud キーチェーンで同期しない・ThisDeviceOnly）。端末ごとの ID にするため。
//

import Foundation
import Security

final class KeychainAnonymousIDStore: AnonymousIDStore {
    enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    private let service: String
    private let account = "anonymous-id"

    /// service はテストで本番の項目と分けるために渡せる
    init(service: String = "\(Bundle.main.bundleIdentifier ?? "Kobosu").anonymous-id") {
        self.service = service
    }

    func currentID() throws -> String {
        if let id = try readID() {
            return id
        }
        let id = UUID().uuidString
        try save(id)
        return id
    }

    func deleteID() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// 項目があれば中身だけを書き換える（消してから作り直すと、途中で失敗したときに ID が無くなる）。
    /// 項目が壊れていても書き直す（控えの ID なので、正しい値で上書きしてよい）
    func replaceID(with id: String) throws {
        if (try? readID()) == id {
            return
        }
        let attributes = [kSecValueData as String: Data(id.utf8)]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            try save(id)
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func readID() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let id = String(data: data, encoding: .utf8), !id.isEmpty else {
                throw KeychainError.invalidData
            }
            return id
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func save(_ id: String) throws {
        var query = baseQuery
        query[kSecValueData as String] = Data(id.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecAttrSynchronizable as String] = false
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
