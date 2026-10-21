//
//  MaskingReview.swift
//  Kobosu
//
//  投稿の前の伏せ字の確認。見つけた候補ごとに、伏せるか・そのままにするかを本人が選ぶ（最初はすべて伏せる）。
//  候補の範囲は、候補を探したときの本文（text）の中でだけ使う。本文を書き直したら、もう一度探す。
//

import Foundation

nonisolated struct MaskingReview: Hashable, Sendable {
    /// 候補を探した本文
    let text: String
    let candidates: [MaskingCandidate]
    /// 伏せる候補の番号（candidates の添字）
    private(set) var maskedIndices: Set<Int>

    init(text: String, candidates: [MaskingCandidate]) {
        self.text = text
        self.candidates = candidates
        maskedIndices = Set(candidates.indices)
    }

    func isMasked(at index: Int) -> Bool {
        maskedIndices.contains(index)
    }

    mutating func setMasked(_ masked: Bool, at index: Int) {
        guard candidates.indices.contains(index) else {
            return
        }
        if masked {
            maskedIndices.insert(index)
        } else {
            maskedIndices.remove(index)
        }
    }

    /// 伏せると選んだ候補を伏せ字にした本文。これを投稿する
    var result: String {
        MaskingDetector.masked(text, ranges: maskedIndices.sorted().map { candidates[$0].range })
    }

    /// 伏せ字にすると上限の文字数を超える（1 文字の名前を「〇〇」にすると 1 文字増える）
    var isOverLimit: Bool {
        result.count > Post.maxBodyLength
    }
}
