//
//  UITestLaunch.swift
//  Kobosu
//
//  UI テスト用の起動引数のうち、下書きとタイムラインのデータに関わるもの。
//  初回の画面とアプリロックは OnboardingStatus、Firebase につながない起動は FirebaseSetup が扱う。
//

import Foundation

nonisolated enum UITestLaunch {
    /// 起動時に下書きを消す（前のテストで書いた下書きが残らないように）
    static let clearDraftArgument = "-uitest-clear-draft"
    /// ローカルの実装に、他の人の投稿（Preview と同じデモデータ）を置いて起動する
    static let seedPostsArgument = "-uitest-seed-posts"

    /// UI テストの起動引数に合わせて、端末に保存した値を書き換える
    static func applyLaunchArguments(_ arguments: [String], to defaults: UserDefaults) {
        if arguments.contains(clearDraftArgument) {
            defaults.removeObject(forKey: UserDefaultsComposeDraftStore.key)
        }
    }

    /// ローカルの実装に他の人の投稿を置くか
    static func seedsPosts(arguments: [String]) -> Bool {
        arguments.contains(seedPostsArgument)
    }
}
