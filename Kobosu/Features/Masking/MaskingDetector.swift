//
//  MaskingDetector.swift
//  Kobosu
//
//  投稿の本文から伏せ字の候補を端末内で探す（サーバーには送らない）。
//  - NLTagger（.nameType）: 人名・地名・組織名
//  - NSDataDetector: 電話番号・住所・URL
//  - 正規表現: メールアドレス・郵便番号・電話番号と、日本語の「〇〇さん」「〇〇市」「〇〇小学校」のような形
//  日本語の固有表現の抽出は精度に限りがあるので、取りこぼしも誤検知もありうる。投稿は止めない。
//

import Foundation
import NaturalLanguage

nonisolated enum MaskingDetector {
    /// 伏せ字にした部分に入れる文字。長さで中身が推測されないよう、元の長さにかかわらず同じにする
    static let maskText = "〇〇"

    /// 伏せ字の候補。本文の前から順に並べ、重なった候補は 1 つにまとめる
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

    private static func detectedData(in text: String) -> [(MaskingCandidate.Kind, Range<String.Index>)] {
        let types: NSTextCheckingResult.CheckingType = [.phoneNumber, .address, .link]
        guard let detector = try? NSDataDetector(types: types.rawValue) else {
            return []
        }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
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
        patterns.flatMap { pattern in
            let kind = pattern.kind
            guard let regex = try? NSRegularExpression(pattern: pattern.regex) else {
                return [(MaskingCandidate.Kind, Range<String.Index>)]()
            }
            return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
                guard let range = Range(match.range(at: pattern.group), in: text) else {
                    return nil
                }
                if kind == .personName, familyWords.contains(String(text[range])) {
                    return nil
                }
                return (kind, range)
            }
        }
    }

    nonisolated private struct Pattern: Sendable {
        let kind: MaskingCandidate.Kind
        let regex: String
        /// 候補にするグループの番号（0 は一致した全体）
        var group = 0
    }

    private static let patterns: [Pattern] = [
        Pattern(kind: .email, regex: #"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"#),
        Pattern(kind: .postalCode, regex: #"〒?\s?[0-9０-９]{3}[-ー－][0-9０-９]{4}"#),
        Pattern(kind: .phoneNumber, regex: #"0[0-9０-９]{1,4}[-ー－]?[0-9０-９]{1,4}[-ー－]?[0-9０-９]{3,4}"#),
        // 「田中さん」「タカシくん」の名前の部分
        Pattern(kind: .personName, regex: #"([一-龥々]{1,4}|[ァ-ヶー]{2,8})(?:さん|くん|君|ちゃん|様|さま|氏)"#, group: 1),
        // 「〇〇県〇〇市」「〇〇区」「〇〇駅」
        Pattern(kind: .placeName, regex: #"[一-龥々ヶ]{1,5}(?:都|道|府|県|市|区|町|村|駅)"#),
        // 「〇〇小学校」「さくら保育園」「〇〇病院」
        Pattern(
            kind: .organizationName,
            regex: #"(?:[一-龥々ァ-ヶーA-Za-z0-9]{1,10}|[ぁ-ん]{2,4})(?:小学校|中学校|高等学校|高校|大学|幼稚園|保育園|保育所|こども園|病院|医院|クリニック|銀行|株式会社)"#
        ),
        // 「株式会社〇〇」
        Pattern(kind: .organizationName, regex: #"株式会社[一-龥々ァ-ヶーA-Za-z0-9]{1,10}"#)
    ]

    /// 「〇〇さん」の形でも、人の名前ではない家族や立場の呼び方
    private static let familyWords: Set<String> = [
        "お義母", "お義父", "義母", "義父", "お母", "お父", "母", "父", "お姉", "お兄", "姉", "兄", "妹", "弟",
        "お嫁", "嫁", "お婿", "婿", "旦那", "奥", "お子", "子", "息子", "娘", "赤", "おば", "おじ", "叔母", "叔父",
        "伯母", "伯父", "おばあ", "おじい", "祖母", "祖父", "義姉", "義兄", "義妹", "義弟", "親戚", "先生", "店員",
        "隣", "近所", "ママ", "パパ", "ママ友", "パパ友", "お客", "皆", "誰", "子供", "子ども", "大家", "上司", "部長", "課長"
    ]

    // MARK: - まとめる

    private static func merged(_ found: [(MaskingCandidate.Kind, Range<String.Index>)], in text: String) -> [MaskingCandidate] {
        // 前から順に、同じ位置なら長いほうを先に並べる
        let sorted = found.sorted { lhs, rhs in
            lhs.1.lowerBound == rhs.1.lowerBound ? lhs.1.upperBound > rhs.1.upperBound : lhs.1.lowerBound < rhs.1.lowerBound
        }
        var result: [(MaskingCandidate.Kind, Range<String.Index>)] = []
        for (kind, range) in sorted where !range.isEmpty {
            if let last = result.last, last.1.overlaps(range) {
                // 重なった候補は 1 つにまとめ、種類は長いほうに合わせる
                let union = last.1.lowerBound..<max(last.1.upperBound, range.upperBound)
                let longer = text.distance(from: range.lowerBound, to: range.upperBound)
                    > text.distance(from: last.1.lowerBound, to: last.1.upperBound) ? kind : last.0
                result[result.count - 1] = (longer, union)
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
