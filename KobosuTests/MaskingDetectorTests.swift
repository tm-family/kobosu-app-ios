//
//  MaskingDetectorTests.swift
//  KobosuTests
//
//  NLTagger の結果は OS の版で変わりうるので、正規表現と NSDataDetector で見つかるものを中心に確かめる。
//

import Foundation
@testable import Kobosu
import Testing

struct MaskingDetectorTests {
    private func candidates(_ text: String) -> [MaskingCandidate] {
        MaskingDetector.candidates(in: text)
    }

    private func texts(_ text: String, kind: MaskingCandidate.Kind) -> [String] {
        candidates(text).filter { $0.kind == kind }.map(\.text)
    }

    @Test
    func detectsPersonNameWithHonorific() {
        let found = candidates("昨日も田中さんに嫌みを言われた。")
        #expect(found.contains { $0.text.contains("田中") && $0.kind == .personName })
        #expect(texts("タカシくんがまた来た", kind: .personName).contains { $0.contains("タカシ") })
    }

    /// 家族や立場の呼び方・「〜様」の言葉は人の名前にしない
    @Test(arguments: Self.notNameTexts)
    func familyWordsAreNotPersonNames(text: String) {
        #expect(texts(text, kind: .personName).isEmpty)
    }

    nonisolated private static let notNameTexts: [String] = [
        "お義母さんに言われた", "旦那さんが手伝わない", "お隣さんの声", "お子さんが泣いた", "皆さんおつかれさま",
        "同様に仕様が変わった", "彼氏さんとお客様", "ご苦労様です", "うちの姑さんと孫さん", "ご主人様の実家"
    ]

    /// 1 文字の家族の呼び方で終わる名前（「花子」の「子」）は外さない。「﨑」「𠮷」のような漢字も名前にする
    @Test
    func detectsNamesEndingWithFamilyLetterAndRareKanji() {
        #expect(texts("花子さんが来た", kind: .personName) == ["花子"])
        #expect(texts("山﨑さんと𠮷田さん", kind: .personName) == ["山﨑", "𠮷田"])
    }

    /// 地名・組織名の形をしていても、特定の場所や組織を指さない言葉は候補にしない
    @Test(arguments: Self.genericTexts)
    func genericWordsAreNotPlacesOrOrganizations(text: String) {
        #expect(texts(text, kind: .placeName).isEmpty)
        #expect(texts(text, kind: .organizationName).isEmpty)
    }

    nonisolated private static let genericTexts: [String] = [
        "柔道を習っている", "都合が悪い", "近くの病院に行った", "総合病院に行った", "都市部に住んでいる", "政府の方針"
    ]

    /// 番号は全体を 1 つの候補にする（一部だけ見つかって残りが見えたままにならない）
    @Test(arguments: ["090-1234-5678", "09012345678", "03-1234-5678", "０９０－１２３４－５６７８", "０３－１２３４－５６７８"])
    func detectsWholePhoneNumber(number: String) {
        let found = candidates("電話は\(number)です")
        #expect(found.contains { $0.kind == .phoneNumber && $0.text == number })
    }

    /// 長い数字の一部を郵便番号にしない
    @Test
    func postalCodeNeedsDigitBoundary() {
        #expect(texts("注文番号 9123-45678 です", kind: .postalCode).isEmpty)
        #expect(candidates("〒１２３－４５６７ に送った").contains { $0.text.contains("１２３－４５６７") })
    }

    @Test
    func allPatternsCompile() {
        #expect(MaskingDetector.invalidPatterns.isEmpty)
    }

    @Test
    func detectsEmailAddress() {
        let found = candidates("連絡は taro.yamada+kobosu@example.com まで")
        let email = found.first { $0.kind == .email }
        #expect(email?.text == "taro.yamada+kobosu@example.com")
    }

    @Test
    func detectsPostalCodeAndPlaceNames() {
        let text = "〒123-4567 東京都新宿区に住んでいて、新宿駅をよく使う"
        // 郵便番号は、続く住所とまとめて 1 つの候補になることがある
        #expect(candidates(text).contains { $0.text.contains("〒123-4567") })
        let places = candidates(text).filter { $0.kind == .placeName || $0.kind == .address }.map(\.text)
        #expect(places.contains { $0.contains("東京都") })
        #expect(places.contains { $0.contains("新宿駅") })
    }

    @Test
    func detectsOrganizationNames() {
        #expect(texts("さくら小学校の役員になった", kind: .organizationName).contains { $0.contains("さくら小学校") })
        #expect(texts("ひまわり保育園のお迎え", kind: .organizationName).contains { $0.contains("ひまわり保育園") })
        #expect(candidates("夫は株式会社カナリアに勤めている").contains { $0.text.contains("株式会社カナリア") })
    }

    @Test
    func detectsLink() {
        #expect(candidates("ここに書いた https://example.com/diary を見て").contains { $0.kind == .link })
    }

    @Test
    func plainFeelingHasNoCandidates() {
        #expect(candidates("きょうも、つかれた。").isEmpty)
        #expect(candidates("").isEmpty)
    }

    /// 候補は前から順に並び、重ならない
    @Test
    func candidatesAreSortedAndDoNotOverlap() {
        let text = "田中さんの電話 090-1234-5678 と tanaka@example.com、〒123-4567"
        let found = candidates(text)
        #expect(!found.isEmpty)
        for (lhs, rhs) in zip(found, found.dropFirst()) {
            #expect(lhs.range.upperBound <= rhs.range.lowerBound)
        }
        for candidate in found {
            #expect(String(text[candidate.range]) == candidate.text)
        }
    }

    /// 種類の違う候補が重なったら 1 つにまとめ、同じ長さなら優先する種類にする。
    /// 「012-3456」は郵便番号と電話番号の両方の正規表現に一致する（NSDataDetector の結果に左右されない入力にする）
    @Test
    func overlappingCandidatesOfDifferentKindsAreMerged() {
        let found = candidates("番号は 012-3456 です").filter { $0.text.contains("012-3456") }
        #expect(found.count == 1)
        #expect(found.first?.text == "012-3456")
        #expect(found.first?.kind == .phoneNumber)
    }

    /// 改行をまたいでも、行ごとに候補を見つける
    @Test
    func detectsAcrossLines() {
        let text = "田中さんから電話。\n090-1234-5678\nまたかけてくる"
        #expect(texts(text, kind: .personName) == ["田中"])
        #expect(texts(text, kind: .phoneNumber) == ["090-1234-5678"])
    }

    /// 400 字の本文でも、候補の範囲が本文と一致する
    @Test
    func handlesLongBody() {
        let text = String(repeating: "きょうもつかれた。", count: 40) + "田中さん"
        let found = candidates(text)
        #expect(found.map(\.text) == ["田中"])
        for candidate in found {
            #expect(String(text[candidate.range]) == candidate.text)
        }
    }

    @Test
    func maskedReplacesRangesWithMaskText() throws {
        let text = "田中さんに 090-1234-5678 を教えた"
        let name = try #require(text.range(of: "田中"))
        let phone = try #require(text.range(of: "090-1234-5678"))
        #expect(MaskingDetector.masked(text, ranges: [phone, name]) == "〇〇さんに 〇〇 を教えた")
    }

    @Test
    func maskedMergesOverlappingRanges() throws {
        let text = "東京都新宿区"
        let first = try #require(text.range(of: "東京都新"))
        let second = try #require(text.range(of: "新宿区"))
        #expect(MaskingDetector.masked(text, ranges: [first, second]) == "〇〇")
        #expect(MaskingDetector.masked(text, ranges: []) == text)
    }

    @Test
    func maskingAllCandidatesRemovesEmailAndPhone() {
        let text = "メールは hanako@example.com、電話は 080-9876-5432"
        let masked = MaskingDetector.masked(text, ranges: candidates(text).map(\.range))
        #expect(!masked.contains("hanako@example.com"))
        #expect(!masked.contains("9876"))
    }
}
