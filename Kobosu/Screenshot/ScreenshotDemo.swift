//
//  ScreenshotDemo.swift
//  Kobosu
//
//  App Store 用スクリーンショットの撮影モード。
//  Tools/capture_screenshots.sh が次の起動引数でアプリを起動し、目的の画面をデモデータで開かせる。
//
//    -screenshot-demo -screenshot-scene <Scene の rawValue> -AppleLanguages (<言語>) -AppleLocale <ロケール>
//
//  画面を足すときは、Scene に case を足し、Kobosu.swift の rootView で開く画面を返し、
//  AppStore/screenshots.json の scenes に同じ rawValue を足す（突き合わせは Tools/app_store_config.py が行う）。
//  デモデータは実データと混ざらないよう、撮影モードのときだけメモリ上やインメモリのストアに用意する。
//

import Foundation

enum ScreenshotDemo {
    /// 撮る画面。rawValue が AppStore/screenshots.json の scene と対応する
    enum Scene: String {
        case home
    }

    /// 撮影モードで起動しているか
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-screenshot-demo")

    /// 撮影モードで開く画面。撮影モードでないときと、知らない値を渡されたときは nil
    static let scene: Scene? = {
        guard isEnabled else {
            return nil
        }
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot-scene"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return Scene(rawValue: arguments[index + 1])
    }()

    // MARK: - デモデータ（実在の人名・地名は書かない。撮影は言語ごとに行うので、文は String Catalog から読む）

    /// デモの自分の匿名 ID
    static let myID = "screenshot-demo-me"

    /// ノートに出す自分の投稿。「うちも同じ」の人数とスタンプの内訳が見えるよう、共感を多めに付ける
    static func myPost(now: Date = Date()) -> Post {
        Post(
            id: "screenshot-demo-mine",
            body: String(localized: "お義母さんからの電話、今日で 3 回目。鳴るたびに体がこわばる。"),
            category: .inLaws,
            createdAt: now.addingTimeInterval(-6 * 60 * 60),
            stampCounts: [.sameHere: 41, .understand: 24, .hardDay: 12, .wellDone: 8]
        )
    }

    /// 投稿の画面に出す書きかけの下書き
    static func draft() -> ComposeDraft {
        ComposeDraft(body: String(localized: "ほんとは「ありがとう」って、ひとこと言ってほしかっただけ。"), category: .partner)
    }
}
