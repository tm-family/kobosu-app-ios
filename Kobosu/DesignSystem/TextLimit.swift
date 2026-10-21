//
//  TextLimit.swift
//  Kobosu
//
//  入力欄の文字数の上限。文字数は見た目の 1 文字（Character）で数える（絵文字や濁点の結合も 1 文字）。
//

import Foundation

nonisolated enum TextLimit {
    /// 上限を超えた分を切り落とす。上限以内ならそのまま返す
    static func clamped(_ text: String, to limit: Int) -> String {
        guard text.count > limit else {
            return text
        }
        return String(text.prefix(max(limit, 0)))
    }
}
