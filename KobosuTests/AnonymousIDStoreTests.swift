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

    @Test
    func keychainDeleteWithoutIDSucceeds() throws {
        let store = KeychainAnonymousIDStore(service: "KobosuTests.anonymous-id.\(UUID().uuidString)")
        try store.deleteID()
    }
}
