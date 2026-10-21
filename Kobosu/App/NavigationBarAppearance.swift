//
//  NavigationBarAppearance.swift
//  Kobosu
//
//  ナビゲーションバーの見出しを Zen Maru Gothic にする（Large Title 32pt Bold・タイトル 17pt Bold）。
//  SwiftUI の navigationTitle には書体を渡せないので、UIKit の appearance で指定する。
//

import UIKit

enum NavigationBarAppearance {
    static func apply() {
        let appearance = UINavigationBar.appearance()
        if let largeTitle = scaledFont(.bold, size: 32, textStyle: .largeTitle) {
            appearance.largeTitleTextAttributes = [.font: largeTitle, .foregroundColor: UIColor(resource: .ink)]
        }
        if let title = scaledFont(.bold, size: 17, textStyle: .headline) {
            appearance.titleTextAttributes = [.font: title, .foregroundColor: UIColor(resource: .ink)]
        }
    }

    /// Dynamic Type で拡大縮小する Zen Maru Gothic
    private static func scaledFont(_ weight: ZenMaruGothic, size: CGFloat, textStyle: UIFont.TextStyle) -> UIFont? {
        guard let font = UIFont(name: weight.rawValue, size: size) else {
            return nil
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }
}
