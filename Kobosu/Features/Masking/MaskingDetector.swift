//
//  MaskingDetector.swift
//  Kobosu
//
//  投稿の本文から伏せ字の候補を端末内で探す（サーバーには送らない）。
//  - NLTagger（.nameType）: 人名・地名・組織名
//  - NSDataDetector: 電話番号・住所・URL
//  - 正規表現: メールアドレス・郵便番号・電話番号と、日本語の「〇〇さん」「〇〇市」「〇〇小学校」のような形
//  日本語の固有表現の抽出は精度に限りがあるので、取りこぼしも誤検知もありうる。投稿は止めない。
//  400 字で数十ミリ秒かかるので、メインスレッドの外で呼ぶ（呼ぶ側で Task.detached などにする）。
//

import Foundation
import NaturalLanguage

nonisolated enum MaskingDetector {
    /// 伏せ字にした部分に入れる文字。長さで中身が推測されないよう、元の長さにかかわらず同じにする
    static let maskText = "〇〇"

    /// 伏せ字の候補。本文の前から順に並べ、重なった候補は 1 つにまとめる。
    /// 候補の range はこの text の中でだけ使える（本文を書き換えたら、もう一度探す）
    static func candidates(in text: String) -> [MaskingCandidate] {
        guard !text.isEmpty else {
            return []
        }
        let found = taggedNames(in: text) + detectedData(in: text) + patternMatches(in: text)
        return merged(found.map { ($0.0, trimmed($0.1, in: text)) }, in: text)
    }

    /// ranges の部分を maskText に置き換えた本文。ranges は text の中の範囲で、重なっていてもよい
    static func masked(_ text: String, ranges: [Range<String.Index>]) -> String {
        var result = text
        let sorted = mergedRanges(ranges)
        // 後ろから置き換えて、前の範囲の位置がずれないようにする
        for range in sorted.reversed() {
            result.replaceSubrange(range, with: maskText)
        }
        return result
    }

    // MARK: - 検知

    private static func taggedNames(in text: String) -> [(MaskingCandidate.Kind, Range<String.Index>)] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.setLanguage(language(of: text), range: text.startIndex..<text.endIndex)
        var found: [(MaskingCandidate.Kind, Range<String.Index>)] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            switch tag {
            case .personalName:
                found.append((.personName, range))
            case .placeName:
                found.append((.placeName, range))
            case .organizationName:
                found.append((.organizationName, range))
            default:
                break
            }
            return true
        }
        return found
    }

    /// NLTagger に渡す言語。かなが入っていれば日本語にする（漢字の多い短い文は中国語と判定されることがあるため）
    private static func language(of text: String) -> NLLanguage {
        if text.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) }) {
            return .japanese
        }
        return NLLanguageRecognizer.dominantLanguage(for: text) ?? .japanese
    }

    private static func detectedData(in text: String) -> [(MaskingCandidate.Kind, Range<String.Index>)] {
        guard let dataDetector else {
            return []
        }
        let matches = dataDetector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else {
                return nil
            }
            switch match.resultType {
            case .phoneNumber:
                return (.phoneNumber, range)
            case .address:
                return (.address, range)
            case .link:
                // メールアドレスは mailto のリンクとして見つかるので、メールアドレスとして扱う
                return (match.url?.scheme == "mailto" ? .email : .link, range)
            default:
                return nil
            }
        }
    }

    private static func patternMatches(in text: String) -> [(MaskingCandidate.Kind, Range<String.Index>)] {
        compiledPatterns.flatMap { pattern, regex in
            regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
                guard let range = Range(match.range(at: pattern.group), in: text), !pattern.excludes(text, range) else {
                    return nil
                }
                return (pattern.kind, range)
            }
        }
    }

    private static let dataDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType([.phoneNumber, .address, .link]).rawValue
    )

    // MARK: - 正規表現

    nonisolated private struct Pattern: Sendable {
        let kind: MaskingCandidate.Kind
        let regex: String
        /// 候補にするグループの番号（0 は一致した全体）
        var group = 0
        /// 一致しても候補にしないもの（誤検知を外す）
        var excludes: @Sendable (String, Range<String.Index>) -> Bool = { _, _ in false }
    }

    /// 漢字（「﨑」「𠮷」なども含める）
    private static let han = #"[\p{Han}々〆ヶ]"#
    /// 数字の前後に数字が続かない（長い数字の一部を電話番号などにしない）
    private static let digitBefore = #"(?<![0-9０-９])"#
    private static let digitAfter = #"(?![0-9０-９])"#
    private static let digit = "[0-9０-９]"
    private static let hyphen = "[-ー－‐]"

    private static let patterns: [Pattern] = [
        Pattern(kind: .email, regex: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#),
        Pattern(kind: .postalCode, regex: #"〒?\s?"# + digitBefore + "\(digit){3}\(hyphen)\(digit){4}" + digitAfter),
        Pattern(
            kind: .phoneNumber,
            regex: digitBefore + "[0０]\(digit){1,4}\(hyphen)?\(digit){1,4}\(hyphen)?\(digit){3,4}" + digitAfter
        ),
        // 「田中さん」「タカシくん」の名前の部分
        Pattern(
            kind: .personName,
            regex: "(\(han){1,4}|[ァ-ヶー]{2,8})(?:さん|くん|君|ちゃん|様|さま|氏)",
            group: 1,
            excludes: { text, range in isNotName(text, range) }
        ),
        // 「〇〇県〇〇市」「〇〇区」「〇〇駅」。「道」「都」「府」は誤検知が多い（柔道・都合・政府）ので、名前で書く
        Pattern(
            kind: .placeName,
            regex: "北海道|東京都|京都府|大阪府|\(han){1,5}(?:県|市|区|町|村|駅)",
            excludes: { text, range in genericPlaces.contains(String(text[range])) }
        ),
        // 「〇〇小学校」「さくら保育園」「〇〇病院」
        Pattern(
            kind: .organizationName,
            regex: "(?:(?:\(han)|[ァ-ヶーA-Za-z0-9]){1,10}|[ぁ-ん]{2,4})" + organizationSuffix,
            excludes: { text, range in isGenericOrganization(text, range) }
        ),
        // 「株式会社〇〇」
        Pattern(kind: .organizationName, regex: "株式会社(?:\(han)|[ァ-ヶーA-Za-z0-9]){1,10}")
    ]

    private static let organizationSuffix = "(?:小学校|中学校|高等学校|高校|大学|幼稚園|保育園|保育所|こども園|病院|医院|クリニック|銀行|株式会社)"
    private static let organizationSuffixAtEnd = try? NSRegularExpression(pattern: organizationSuffix + "$")

    /// コンパイルできなかった正規表現（テストで空であることを確かめる）
    static var invalidPatterns: [String] {
        let regexes = patterns.map(\.regex) + [organizationSuffix + "$"]
        return regexes.filter { (try? NSRegularExpression(pattern: $0)) == nil }
    }

    private static let compiledPatterns: [(Pattern, NSRegularExpression)] = patterns.compactMap { pattern in
        (try? NSRegularExpression(pattern: pattern.regex)).map { (pattern, $0) }
    }

    // MARK: - 誤検知を外す

    /// 「〇〇さん」の形でも、人の名前ではない家族や立場の呼び方（名前の部分がこれと同じなら外す）
    private static let notNames: Set<String> = [
        "お義母", "お義父", "義母", "義父", "お母", "お父", "母", "父", "お姉", "お兄", "姉", "兄", "妹", "弟",
        "お嫁", "嫁", "お婿", "婿", "旦那", "奥", "お子", "子", "息子", "娘", "孫", "赤", "おば", "おじ", "叔母", "叔父",
        "伯母", "伯父", "おばあ", "おじい", "祖母", "祖父", "義姉", "義兄", "義妹", "義弟", "親戚", "先生", "店員",
        "隣", "近所", "ママ", "パパ", "ママ友", "パパ友", "お客", "客", "皆", "誰", "子供", "子ども", "大家", "上司", "部長", "課長",
        "姑", "舅", "主人", "夫", "妻", "彼", "彼氏", "彼女", "同", "仕", "苦労", "ご苦労", "神", "仏", "王", "各", "貴", "殿", "皆様"
    ]

    /// 名前の部分がこれで終わるなら外す（「うちのお客様」「ご主人様」のように前に語が付いても外すため）。1 文字の語は後方一致にしない（「花子さん」の「子」）
    private static let notNameSuffixes = notNames.filter { $0.count >= 2 }

    private static func isNotName(_ text: String, _ range: Range<String.Index>) -> Bool {
        let name = String(text[range])
        if notNames.contains(name) {
            return true
        }
        // 名前の前のかなも含めて見る（「お客」の「お」は漢字の名前の部分に入らない）
        let start = text.index(range.lowerBound, offsetBy: -3, limitedBy: text.startIndex) ?? text.startIndex
        let context = text[start..<range.upperBound]
        return notNameSuffixes.contains { context.hasSuffix($0) }
    }

    /// 地名の形でも、特定の場所を指さない言葉
    private static let genericPlaces: Set<String> = [
        "都市", "地区", "学区", "下町", "農村", "漁村", "山村", "市町村", "区市町村", "都道府県", "選挙区", "特区", "各駅", "最寄駅",
        "市区町村", "城下町", "門前町", "全県", "他県", "隣県", "隣町", "隣村", "隣駅", "次駅", "同市", "同区", "同町", "当駅", "始発駅", "終着駅"
    ]

    /// 組織の名前の前に付いても、特定の組織を指さない言葉
    private static let genericOrganizationPrefixes: Set<String> = [
        "総合", "大学", "市立", "県立", "国立", "私立", "公立", "都立", "府立", "区立", "町立", "村立", "近所", "地元", "近く", "大きな", "小さな",
        "個人", "歯科", "小児科", "産婦人科", "動物", "大", "小", "中", "同じ", "別の", "通う", "通っている"
    ]

    private static func isGenericOrganization(_ text: String, _ range: Range<String.Index>) -> Bool {
        let matched = String(text[range])
        guard let match = organizationSuffixAtEnd?.firstMatch(in: matched, range: NSRange(matched.startIndex..., in: matched)),
              let suffixRange = Range(match.range, in: matched) else {
            return false
        }
        let prefix = String(matched[..<suffixRange.lowerBound])
        // 「近くの病院」の「くの」のように、助詞を含むかなは名前ではない
        if prefix.allSatisfy({ ("ぁ"..."ん").contains($0) }) {
            return prefix.contains { "のにをはがでとへもや".contains($0) }
        }
        return genericOrganizationPrefixes.contains(prefix)
    }

    // MARK: - まとめる

    /// 同じ長さの候補が重なったときに、どちらの種類にするか（小さいほど優先）
    private static func priority(of kind: MaskingCandidate.Kind) -> Int {
        switch kind {
        case .email:
            0
        case .phoneNumber:
            1
        case .postalCode:
            2
        case .link:
            3
        case .address:
            4
        case .personName:
            5
        case .organizationName:
            6
        case .placeName:
            7
        }
    }

    private static func merged(_ found: [(MaskingCandidate.Kind, Range<String.Index>)], in text: String) -> [MaskingCandidate] {
        // 前から順に、同じ位置なら長いほうを、同じ長さなら優先する種類を先に並べる
        let sorted = found.sorted { lhs, rhs in
            if lhs.1.lowerBound != rhs.1.lowerBound {
                return lhs.1.lowerBound < rhs.1.lowerBound
            }
            if lhs.1.upperBound != rhs.1.upperBound {
                return lhs.1.upperBound > rhs.1.upperBound
            }
            return priority(of: lhs.0) < priority(of: rhs.0)
        }
        var result: [(MaskingCandidate.Kind, Range<String.Index>)] = []
        for (kind, range) in sorted where !range.isEmpty {
            if let last = result.last, last.1.overlaps(range) {
                // 重なった候補は 1 つにまとめ、種類は長いほう（同じ長さなら優先する種類）に合わせる
                let union = last.1.lowerBound..<max(last.1.upperBound, range.upperBound)
                let lastLength = text.distance(from: last.1.lowerBound, to: last.1.upperBound)
                let length = text.distance(from: range.lowerBound, to: range.upperBound)
                let wins = length > lastLength || (length == lastLength && priority(of: kind) < priority(of: last.0))
                result[result.count - 1] = (wins ? kind : last.0, union)
            } else {
                result.append((kind, range))
            }
        }
        return result.map { MaskingCandidate(kind: $0.0, range: $0.1, text: String(text[$0.1])) }
    }

    /// 前後の空白・改行を範囲から外す（NSDataDetector は電話番号の前の空白を含めることがある）
    private static func trimmed(_ range: Range<String.Index>, in text: String) -> Range<String.Index> {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, text[lower].isWhitespace {
            lower = text.index(after: lower)
        }
        while lower < upper, text[text.index(before: upper)].isWhitespace {
            upper = text.index(before: upper)
        }
        return lower..<upper
    }

    private static func mergedRanges(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) where !range.isEmpty {
            if let last = result.last, last.upperBound >= range.lowerBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}
