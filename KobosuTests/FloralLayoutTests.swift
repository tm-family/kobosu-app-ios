//
//  FloralLayoutTests.swift
//  KobosuTests
//

import CoreGraphics
@testable import Kobosu
import Testing

struct FloralLayoutTests {
    /// 大きな花の、中心から端の方向に花びらが届く長さ（素材の 250×250 の pt。倍率 1 のとき）。
    /// 花びらは 6 枚の楕円（中心 60・長半径 60・短半径 34）なので、向きによって届く長さが違う。
    /// 回す角度ごとに計算した値より少し短くとる（ピンク 0 度: 上 120・右 106.7、ラベンダー 20 度: 左 118.5、ブルー 10 度: 右 113.9・下 118.5）
    private enum Reach {
        static let pinkUp: CGFloat = 118
        static let pinkRight: CGFloat = 105
        static let lavenderLeft: CGFloat = 116
        static let blueRight: CGFloat = 112
        static let blueDown: CGFloat = 116
    }

    /// 確かめる画面の大きさ（iPhone SE・17 Pro・Pro Max・iPhone の横向き・iPad 13 インチの縦と横）
    nonisolated private static let screenSizes: [CGSize] = [
        CGSize(width: 375, height: 667),
        CGSize(width: 402, height: 874),
        CGSize(width: 440, height: 956),
        CGSize(width: 874, height: 402),
        CGSize(width: 1032, height: 1376),
        CGSize(width: 1376, height: 1032)
    ]

    /// 390×844 では、素材の README の座標・倍率・角度と、background_transparent.svg の重なり順のとおりに置く
    @Test
    func referenceSizeMatchesReadme() {
        let placements = FloralLayout.placements(in: FloralLayout.referenceSize)
        let expected: [FloralPlacement] = [
            FloralPlacement(part: .leaf, anchor: CGPoint(x: 250, y: 255), scale: 1, rotation: 140),
            FloralPlacement(part: .leaf, anchor: CGPoint(x: 372, y: 300), scale: 1, rotation: 80),
            FloralPlacement(part: .flowerPink, anchor: CGPoint(x: 330, y: 150), scale: 1.4, rotation: 0),
            FloralPlacement(part: .leaf, anchor: CGPoint(x: 70, y: 450), scale: 1, rotation: -50),
            FloralPlacement(part: .flowerLavender, anchor: CGPoint(x: 40, y: 540), scale: 1.2, rotation: 20),
            FloralPlacement(part: .leaf, anchor: CGPoint(x: 150, y: 640), scale: 1, rotation: 20),
            FloralPlacement(part: .flowerBlue, anchor: CGPoint(x: 345, y: 735), scale: 1.0, rotation: 10),
            FloralPlacement(part: .budPink, anchor: CGPoint(x: 205, y: 345), scale: 0.4, rotation: 0),
            FloralPlacement(part: .budLavender, anchor: CGPoint(x: 95, y: 160), scale: 0.35, rotation: 0)
        ]
        #expect(placements.count == expected.count)
        for (placement, expected) in zip(placements, expected) {
            #expect(placement.part == expected.part)
            #expect(abs(placement.anchor.x - expected.anchor.x) < 0.001, "\(expected.part) \(placement.anchor)")
            #expect(abs(placement.anchor.y - expected.anchor.y) < 0.001, "\(expected.part) \(placement.anchor)")
            #expect(abs(placement.scale - expected.scale) < 0.001)
            #expect(placement.rotation == expected.rotation)
        }
    }

    /// どの大きさでも、ピンクは右上の角に、ラベンダーは左の端に、ブルーは右下の角にかかる
    @Test(arguments: Self.screenSizes)
    func bigFlowersReachEdges(size: CGSize) throws {
        let placements = FloralLayout.placements(in: size)
        let pink = try #require(placements.first { $0.part == .flowerPink })
        let lavender = try #require(placements.first { $0.part == .flowerLavender })
        let blue = try #require(placements.first { $0.part == .flowerBlue })
        // 右上の角: 右端と上端の両方に花びらがかかる
        #expect(size.width - pink.center.x < Reach.pinkRight * pink.scale)
        #expect(pink.center.y < Reach.pinkUp * pink.scale)
        // 左の端: 左端に花びらがかかり、花の中心は画面の高さの中にある
        #expect(lavender.center.x < Reach.lavenderLeft * lavender.scale)
        #expect((0...size.height).contains(lavender.center.y))
        // 右下の角: 右端と下端の両方に花びらがかかる
        #expect(size.width - blue.center.x < Reach.blueRight * blue.scale)
        #expect(size.height - blue.center.y < Reach.blueDown * blue.scale)
    }

    /// 小花と葉は画面の中に置く（端の外に出て見えなくならない）
    @Test(arguments: Self.screenSizes)
    func smallPartsStayOnScreen(size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        for placement in FloralLayout.placements(in: size) where placement.part != .flowerPink
            && placement.part != .flowerLavender && placement.part != .flowerBlue {
            #expect(bounds.contains(placement.anchor), "\(placement.part) \(placement.anchor) が \(size) の外")
        }
    }

    /// 部品の倍率は 390×844 で 1。小さい画面・大きい画面では下限と上限で止める
    @Test
    func scaleIsClamped() {
        #expect(FloralLayout.scale(for: FloralLayout.referenceSize) == 1)
        #expect(FloralLayout.scale(for: CGSize(width: 320, height: 568)) == FloralLayout.scaleRange.lowerBound)
        #expect(FloralLayout.scale(for: CGSize(width: 1376, height: 1032)) == FloralLayout.scaleRange.upperBound)
        #expect(FloralLayout.scale(for: CGSize(width: 440, height: 956)) > 1)
        #expect(FloralLayout.scale(for: .zero) == 1)
    }

    /// 葉は付け根（画像の左から 4pt・上下の中央）を anchor に合わせ、付け根を中心に回す。花は画像の中心が anchor
    @Test
    func leafRotatesAroundItsBase() {
        let flat = FloralPlacement(part: .leaf, anchor: CGPoint(x: 100, y: 100), scale: 1, rotation: 0)
        #expect(flat.center == CGPoint(x: 158, y: 100))
        let down = FloralPlacement(part: .leaf, anchor: CGPoint(x: 100, y: 100), scale: 2, rotation: 90)
        #expect(abs(down.center.x - 100) < 0.001)
        #expect(abs(down.center.y - 216) < 0.001)
        #expect(down.size == CGSize(width: 248, height: 120))
        let flower = FloralPlacement(part: .flowerBlue, anchor: CGPoint(x: 10, y: 20), scale: 1.2, rotation: 10)
        #expect(flower.center == CGPoint(x: 10, y: 20))
        #expect(flower.size == CGSize(width: 300, height: 300))
    }
}
