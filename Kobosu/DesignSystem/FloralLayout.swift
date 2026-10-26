//
//  FloralLayout.swift
//  Kobosu
//
//  背景の花柄の配置（Discussion #76 の Q6）。素材の README の 390×844pt の配置を基準に、画面の大きさに合わせて部品を端に寄せる。
//  - 大きな花は近い端からの距離で置く（右上のピンクは右端と上端から、左のラベンダーは左端から、右下のブルーは右端と下端から）
//  - 間の小花と葉は、画面の幅・高さに対する割合で置く
//  - 部品の大きさは画面の面積に合わせて変え（scale）、小さい画面・大きい画面では上限と下限で止める
//  どの大きさでも、大きな花が角・端にかかるようにする（FloralLayoutTests で確かめる）。
//

import CoreGraphics

/// 部品 1 つの置き方。center は画像の中心の位置（葉も、付け根から計算した画像の中心）
nonisolated struct FloralPlacement: Equatable, Sendable {
    let part: FloralPart
    /// 花の中心・葉の付け根の位置（素材の README の座標にあたるもの）
    let anchor: CGPoint
    /// 素材の大きさに掛ける倍率
    let scale: CGFloat
    /// 回す角度（度。時計回り）
    let rotation: Double

    /// 画面に置く大きさ
    var size: CGSize {
        CGSize(width: part.size.width * scale, height: part.size.height * scale)
    }

    /// 画像の中心の位置。花は anchor と同じ。葉は付け根（左から 4pt・上下の中央）を anchor に合わせ、付け根を中心に回す
    var center: CGPoint {
        guard part == .leaf else {
            return anchor
        }
        // 付け根から画像の中心までの距離（124 の幅の半分 62 から、付け根の 4 を引いたもの）を、回した向きに伸ばす
        let distance = (part.size.width / 2 - FloralLayout.leafBaseInset) * scale
        let radians = rotation * .pi / 180
        return CGPoint(x: anchor.x + distance * cos(radians), y: anchor.y + distance * sin(radians))
    }
}

nonisolated enum FloralLayout {
    /// 素材の配置の基準の大きさ
    static let referenceSize = CGSize(width: 390, height: 844)
    /// 葉の画像の左端から付け根までの距離（leaf.svg の viewBox は -4 -30 124 60）
    static let leafBaseInset: CGFloat = 4
    /// 部品の倍率の下限と上限（iPhone SE で小さくなりすぎず、iPad で大きくなりすぎないように）
    static let scaleRange: ClosedRange<CGFloat> = 0.85...1.6

    /// 素材の README の配置（390×844pt）。重なり順は background_transparent.svg の順（下から）
    private enum Anchor {
        /// 右端と上端からの距離で置く
        case topTrailing
        /// 左端からの距離と、高さの割合で置く
        case leading
        /// 右端と下端からの距離で置く
        case bottomTrailing
        /// 幅・高さの割合で置く
        case proportional
    }

    private struct Reference {
        let part: FloralPart
        let point: CGPoint
        let scale: CGFloat
        let rotation: Double
        let anchor: Anchor
    }

    private static let references: [Reference] = [
        Reference(part: .leaf, point: CGPoint(x: 250, y: 255), scale: 1, rotation: 140, anchor: .proportional),
        Reference(part: .leaf, point: CGPoint(x: 372, y: 300), scale: 1, rotation: 80, anchor: .proportional),
        Reference(part: .flowerPink, point: CGPoint(x: 330, y: 150), scale: 1.4, rotation: 0, anchor: .topTrailing),
        Reference(part: .leaf, point: CGPoint(x: 70, y: 450), scale: 1, rotation: -50, anchor: .proportional),
        Reference(part: .flowerLavender, point: CGPoint(x: 40, y: 540), scale: 1.2, rotation: 20, anchor: .leading),
        Reference(part: .leaf, point: CGPoint(x: 150, y: 640), scale: 1, rotation: 20, anchor: .proportional),
        Reference(part: .flowerBlue, point: CGPoint(x: 345, y: 735), scale: 1.0, rotation: 10, anchor: .bottomTrailing),
        Reference(part: .budPink, point: CGPoint(x: 205, y: 345), scale: 0.4, rotation: 0, anchor: .proportional),
        Reference(part: .budLavender, point: CGPoint(x: 95, y: 160), scale: 0.35, rotation: 0, anchor: .proportional)
    ]

    /// 画面の大きさに合わせた部品の倍率。390×844 で 1。面積の比の平方根を scaleRange で止める
    static func scale(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else {
            return 1
        }
        let ratio = ((size.width * size.height) / (referenceSize.width * referenceSize.height)).squareRoot()
        return min(max(ratio, scaleRange.lowerBound), scaleRange.upperBound)
    }

    /// 画面の大きさに合わせた部品の置き方。並びは重なり順（先に描くものほど下）
    static func placements(in size: CGSize) -> [FloralPlacement] {
        let factor = scale(for: size)
        return references.map { reference in
            FloralPlacement(
                part: reference.part,
                anchor: anchor(of: reference, in: size, factor: factor),
                scale: reference.scale * factor,
                rotation: reference.rotation
            )
        }
    }

    private static func anchor(of reference: Reference, in size: CGSize, factor: CGFloat) -> CGPoint {
        let point = reference.point
        switch reference.anchor {
        case .topTrailing:
            return CGPoint(x: size.width - (referenceSize.width - point.x) * factor, y: point.y * factor)
        case .leading:
            return CGPoint(x: point.x * factor, y: size.height * point.y / referenceSize.height)
        case .bottomTrailing:
            return CGPoint(
                x: size.width - (referenceSize.width - point.x) * factor,
                y: size.height - (referenceSize.height - point.y) * factor
            )
        case .proportional:
            return CGPoint(x: size.width * point.x / referenceSize.width, y: size.height * point.y / referenceSize.height)
        }
    }
}
