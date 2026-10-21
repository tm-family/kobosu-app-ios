//
//  ScreenshotDemoTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct ScreenshotDemoTests {
    @Test
    func demoHasMyPostForNote() async throws {
        let dependencies = AppDependencies.demo()
        let myPosts = try await dependencies.posts.myPosts()
        #expect(myPosts.map(\.id) == [ScreenshotDemo.myPost().id])
        #expect(myPosts.first?.stampCounts[.sameHere] == 41)
    }

    @Test
    func empathyScenePostIsSomeoneElses() async throws {
        let dependencies = AppDependencies.demo()
        let timeline = try await dependencies.posts.timeline(category: nil)
        #expect(timeline.contains { $0.id == ScreenshotDemo.empathyPostID })
        let myPosts = try await dependencies.posts.myPosts()
        #expect(!myPosts.contains { $0.id == ScreenshotDemo.empathyPostID })
    }

    @Test
    func demoHasDraftForCompose() {
        let draft = AppDependencies.demo().drafts.load()
        #expect(draft == ScreenshotDemo.draft())
        #expect(draft?.isEmpty == false)
    }

    /// 撮影モード・Preview で「すべてのデータを削除」を押しても、ふだんの同意の記録（.standard）を消さない
    @Test
    func demoDoesNotEraseStandardDefaults() {
        #expect(AppDependencies.demo().settingsDefaults !== UserDefaults.standard)
    }
}
