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

    /// 家族や立場の呼び方は人の名前にしない
    @Test(arguments: ["お義母さんに言われた", "旦那さんが手伝わない", "お隣さんの声", "お子さんが泣いた", "皆さんおつかれさま"])
    func familyWordsAreNotPersonNames(text: String) {
        #expect(texts(text, kind: .personName).isEmpty)
    }

    @Test(arguments: ["090-1234-5678", "09012345678", "03-1234-5678", "０９０－１２３４－５６７８"])
    func detectsPhoneNumber(number: String) {
        let found = candidates("電話は\(number)です")
        #expect(found.contains { $0.kind == .phoneNumber && $0.text.contains(number.suffix(4)) })
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
        #expect(candidates(text).contains { $0.kind == .postalCode || $0.text.contains("123-4567") })
        let places = candidates(text).filter { $0.kind == .placeName || $0.kind == .address }.map(\.text)
        #expect(places.contains { $0.contains("東京都") })
        #expect(places.contains { $0.contains("新宿駅") })
    }

    @Test
    func detectsOrganizationNames() {
        #expect(texts("さくら小学校の役員になった", kind: .organizationName).contains { $0.contains("さくら小学校") || $0.contains("小学校") })
        #expect(candidates("夫は株式会社カナリアに勤めている").contains { $0.text.contains("カナリア") })
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
