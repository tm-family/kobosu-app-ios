//
//  CategoryEstimator.swift
//  Kobosu
//
//  投稿の本文からカテゴリを端末内で推定する（サーバーには送らない）。
//  カテゴリごとの言葉の一覧（keywords）が本文に出てくる数を数え、いちばん多いカテゴリにする。
//  すべての端末で同じ結果になり、どの言葉で選んだかを説明できる。一覧に無い言い回しは推定できない（nil）。
//  言葉を足すときは keywords に書き足す。実在の人名・地名は入れない。
//

import Foundation

nonisolated enum CategoryEstimator {
    /// カテゴリごとの言葉。「その他」と「未分類」は推定しないので持たない。
    /// ひらがな／カタカナ、全角／半角の違いは数える前にそろえる（normalized）ので、どちらか一方で書けばよい
    static let keywords: [PostCategory: [String]] = [
        .inLaws: [
            "義母", "義父", "義両親", "義実家", "義理の", "義姉", "義妹", "義兄", "義弟",
            "姑", "舅", "しゅうと", "帰省", "同居", "孫の顔"
        ],
        .partner: [
            "夫", "妻", "旦那", "だんな", "嫁", "奥さん", "主人", "パートナー", "配偶者",
            "彼氏", "結婚", "離婚", "二人", "ふたり"
        ],
        .parenting: [
            "子ども", "子供", "こども", "息子", "娘", "赤ちゃん", "育児", "子育て", "寝かしつけ",
            "夜泣き", "授乳", "おむつ", "離乳食", "イヤイヤ期", "反抗期", "保育園", "幼稚園", "学校",
            "宿題", "習い事", "ママ友", "パパ友"
        ],
        .housework: [
            "家事", "洗い物", "皿洗い", "洗濯", "掃除", "料理", "炊事", "片付け", "片づけ",
            "ゴミ出し", "買い出し", "献立", "作り置き", "手伝", "分担", "ワンオペ"
        ],
        .money: [
            "お金", "家計", "出費", "給料", "給与", "貯金", "貯蓄", "ローン", "節約", "生活費",
            "小遣い", "おこづかい", "借金", "収入", "支払い", "浪費", "ボーナス", "年収", "学費"
        ]
    ]

    /// 数える前に取り除く言い回し。言葉の一覧の言葉を含むが、そのカテゴリの話ではないもの（「大丈夫」の「夫」など）
    static let ignoredPhrases = ["大丈夫", "丈夫", "工夫"]

    /// 同じ数のときに選ぶ順（PostCategory の case の順）
    private static let tieBreakOrder: [PostCategory] = PostCategory.allCases.filter { keywords[$0] != nil }

    /// 本文から推定したカテゴリ。どの言葉も出てこなければ nil
    static func estimate(_ text: String) -> PostCategory? {
        let scores = scores(for: text)
        guard let best = scores.values.max(), best > 0 else {
            return nil
        }
        return tieBreakOrder.first { scores[$0] == best }
    }

    /// カテゴリごとの、言葉が本文に出てきた数
    static func scores(for text: String) -> [PostCategory: Int] {
        var normalizedText = normalized(text)
        for phrase in ignoredPhrases.map(normalized) {
            normalizedText = normalizedText.replacingOccurrences(of: phrase, with: " ")
        }
        return keywords.mapValues { words in
            Set(words.map(normalized)).reduce(0) { $0 + occurrences(of: $1, in: normalizedText) }
        }
    }

    /// 全角／半角（英数字・カタカナ）をそろえ、カタカナをひらがなに、英字を小文字にする
    static func normalized(_ text: String) -> String {
        let widthFolded = text.precomposedStringWithCompatibilityMapping
        let hiragana = widthFolded.applyingTransform(.hiraganaToKatakana, reverse: true) ?? widthFolded
        return hiragana.lowercased()
    }

    private static func occurrences(of word: String, in text: String) -> Int {
        guard !word.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: word, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<text.endIndex
        }
        return count
    }
}
