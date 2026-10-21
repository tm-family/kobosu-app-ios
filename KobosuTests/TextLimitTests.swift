//
//  TextLimitTests.swift
//  KobosuTests
//

@testable import Kobosu
import Testing

struct TextLimitTests {
    @Test
    func keepsTextWithinLimit() {
        #expect(TextLimit.clamped("おつかれさま", to: 6) == "おつかれさま")
        #expect(TextLimit.clamped("", to: 400).isEmpty)
    }

    @Test
    func cutsTextOverLimit() {
        #expect(TextLimit.clamped("おつかれさま", to: 3) == "おつか")
    }

    /// 絵文字や結合文字は見た目の 1 文字として数え、途中で切らない
    @Test
    func countsCharactersAsSeen() {
        let family = "👨‍👩‍👧‍👦"
        #expect(TextLimit.clamped(family + family, to: 1) == family)
        let voiced = "か\u{3099}"
        #expect(TextLimit.clamped(voiced + "き", to: 1) == voiced)
    }

    @Test
    func negativeLimitReturnsEmpty() {
        #expect(TextLimit.clamped("本文", to: -1).isEmpty)
    }
}
