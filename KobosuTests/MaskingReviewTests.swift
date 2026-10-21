//
//  MaskingReviewTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct MaskingReviewTests {
    private let text = "田中さんに 090-1234-5678 を教えた"

    private func makeReview() throws -> MaskingReview {
        let name = try #require(text.range(of: "田中"))
        let phone = try #require(text.range(of: "090-1234-5678"))
        return MaskingReview(
            text: text,
            candidates: [
                MaskingCandidate(kind: .personName, range: name, text: "田中"),
                MaskingCandidate(kind: .phoneNumber, range: phone, text: "090-1234-5678")
            ]
        )
    }

    /// 最初はすべて伏せる
    @Test
    func masksAllCandidatesFirst() throws {
        let review = try makeReview()
        #expect(review.isMasked(at: 0))
        #expect(review.isMasked(at: 1))
        #expect(review.result == "〇〇さんに 〇〇 を教えた")
        #expect(!review.isOverLimit)
    }

    /// 候補ごとに、そのままにできる
    @Test
    func keepsCandidatesTurnedOff() throws {
        var review = try makeReview()
        review.setMasked(false, at: 1)
        #expect(review.result == "〇〇さんに 090-1234-5678 を教えた")
        review.setMasked(false, at: 0)
        #expect(review.result == text)
        review.setMasked(true, at: 1)
        #expect(review.result == "田中さんに 〇〇 を教えた")
        // 範囲の外の番号は何もしない
        review.setMasked(false, at: 5)
        #expect(review.result == "田中さんに 〇〇 を教えた")
    }
}
