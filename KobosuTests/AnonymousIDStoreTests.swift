//
//  AnonymousIDStoreTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct AnonymousIDStoreTests {
    @Test
    func inMemoryStoreKeepsIDUntilDeleted() {
        var count = 0
        let store = InMemoryAnonymousIDStore {
            count += 1
            return "id-\(count)"
        }
        #expect(store.currentID() == "id-1")
        #expect(store.currentID() == "id-1")
        store.deleteID()
        #expect(store.currentID() == "id-2")
    }

    /// Keychain に保存した ID は、別のインスタンス（アプリの再起動・再インストール）でも同じ値になる
    @Test
    func keychainStoreKeepsIDAcrossInstances() throws {
        let service = "KobosuTests.anonymous-id.\(UUID().uuidString)"
        let store = KeychainAnonymousIDStore(service: service)
        defer { try? store.deleteID() }

        let id = try store.currentID()
        #expect(!id.isEmpty)
        #expect(try store.currentID() == id)
        #expect(try KeychainAnonymousIDStore(service: service).currentID() == id)

        try store.deleteID()
        let newID = try KeychainAnonymousIDStore(service: service).currentID()
        #expect(newID != id)
    }

    /// 置き換えた ID（Firebase の uid）は、別のインスタンスでも同じ値になる
    @Test
    func keychainStoreReplacesID() throws {
        let service = "KobosuTests.anonymous-id.\(UUID().uuidString)"
        let store = KeychainAnonymousIDStore(service: service)
        defer { try? store.deleteID() }

        _ = try store.currentID()
        try store.replaceID(with: "firebase-uid")
        #expect(try store.currentID() == "firebase-uid")
        #expect(try KeychainAnonymousIDStore(service: service).currentID() == "firebase-uid")
        // 同じ値で置き換えても変わらない
        try store.replaceID(with: "firebase-uid")
        #expect(try store.currentID() == "firebase-uid")
    }

    @Test
    func inMemoryStoreReplacesID() {
        let store = InMemoryAnonymousIDStore(id: "local")
        store.replaceID(with: "firebase-uid")
        #expect(store.currentID() == "firebase-uid")
    }

    @Test
    func keychainDeleteWithoutIDSucceeds() throws {
        let store = KeychainAnonymousIDStore(service: "KobosuTests.anonymous-id.\(UUID().uuidString)")
        try store.deleteID()
    }
}
