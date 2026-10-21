//
//  DesignSystemTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing
import UIKit

struct DesignSystemTests {
    /// 同梱した Zen Maru Gothic が登録されている（登録できないと Font.custom は黙って標準の書体になる）
    @Test(arguments: ZenMaruGothic.allCases)
    func fontIsRegistered(weight: ZenMaruGothic) {
        #expect(UIFont(name: weight.rawValue, size: 15) != nil, "\(weight.rawValue) を登録できていない")
    }

    /// OFL のライセンス文をアプリに同梱している
    @Test
    func fontLicenseIsBundled() throws {
        let url = try #require(Bundle.main.url(forResource: "ZenMaruGothic-OFL", withExtension: "txt"))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("SIL Open Font License"))
    }

    /// パレットの色はライトとダークの両方で用意している
    @Test(arguments: Self.colorNames)
    func colorExistsInLightAndDark(name: String) throws {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil), "\(name) が Asset Catalog に無い")
        let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        if !name.hasPrefix("Gradient") {
            #expect(light != dark, "\(name) にダークモードの色が無い")
        }
    }

    /// ライトモードの値がデザイン案のとおりになっている
    @Test(arguments: [
        ("Paper", 0xFBFAF7),
        ("Card", 0xFFFFFF),
        ("Ink", 0x19171F),
        ("InkSecondary", 0x6B6775),
        ("AccentColor", 0xA100FF),
        ("AccentDeep", 0x7400C2),
        ("Lavender", 0xF4E9FF),
        ("Caution", 0xDE52B0),
        ("GradientPink", 0xDE52B0),
        ("GradientMagenta", 0xBE39D2),
        ("GradientViolet", 0x8B4FEA),
        ("GradientBlue", 0x4B85FD)
    ])
    func lightColorMatchesDesign(name: String, hex: Int) throws {
        let color = try #require(UIColor(named: name, in: .main, compatibleWith: nil))
        let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(light.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        let actual = (Int((red * 255).rounded()) << 16) | (Int((green * 255).rounded()) << 8) | Int((blue * 255).rounded())
        #expect(actual == hex, "\(name): \(String(actual, radix: 16)) != \(String(hex, radix: 16))")
    }

    nonisolated private static let colorNames = [
        "Paper", "Card", "Ink", "InkSecondary", "AccentColor", "AccentDeep", "Lavender", "Caution", "Line",
        "DisabledSurface", "DisabledInk", "SegmentSurface", "GradientPink", "GradientMagenta", "GradientViolet", "GradientBlue"
    ]
}
