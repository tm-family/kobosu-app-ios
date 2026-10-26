//
//  FloralPart.swift
//  Kobosu
//
//  背景の花柄の部品（担当者が用意した SVG。Assets.xcassets の Floral）。部品ごとに置いて、画面の大きさに合わせて端に寄せる。
//  ライトの SVG は素材のまま（色はお知らせの表のとおり）。ダークの SVG は形を変えずに色だけを替えてある（Discussion #76 の Q7 の仮の色）。
//  ダークの色を差し替えるときは、各 imageset の `*_dark.svg` の fill / stroke だけを書き換える。
//
//  | 部位 | ライト | ダーク |
//  | --- | --- | --- |
//  | ピンクの花（外／内） | #F6DCEC / #FBEDF5 | #301C28 / #24141D |
//  | ラベンダーの花（外／内） | #EBDDFA / #F5EEFD | #23182F / #1B1226 |
//  | ブルーの花（外／内） | #DFE7FA / #EEF2FD | #171E2D / #121726 |
//  | 花の中心 | #F4E9FF・#E7D1FA・#FBE3F2・#F2C9E3 | #1C0F29・#2B1B39・#2A1522・#412536 |
//  | 葉（面／葉脈） | #E7EEDD / #D9E3CC | #2B3024 / #3A4132 |
//

import SwiftUI

nonisolated enum FloralPart: CaseIterable, Sendable {
    /// 大きな花（ピンク）。右上に置く
    case flowerPink
    /// 大きな花（ラベンダー）。左の端に置く
    case flowerLavender
    /// 大きな花（ブルー）。右下に置く
    case flowerBlue
    /// 小さな花（ピンク）
    case budPink
    /// 小さな花（ラベンダー）
    case budLavender
    /// 葉。左端が付け根
    case leaf

    /// アセットカタログの画像（生成される ImageResource が MainActor にあるため）
    @MainActor var image: ImageResource {
        switch self {
        case .flowerPink:
            .flowerPink
        case .flowerLavender:
            .flowerLavender
        case .flowerBlue:
            .flowerBlue
        case .budPink:
            .budPink
        case .budLavender:
            .budLavender
        case .leaf:
            .leaf
        }
    }

    /// 素材の大きさ（pt）。花は 250×250 で、中心が花の中心。葉は 124×60 で、左から 4pt・上下の中央が付け根
    var size: CGSize {
        switch self {
        case .flowerPink, .flowerLavender, .flowerBlue, .budPink, .budLavender:
            CGSize(width: 250, height: 250)
        case .leaf:
            CGSize(width: 124, height: 60)
        }
    }
}

#Preview("花柄の部品") {
    let parts = FloralPart.allCases
    HStack(spacing: 0) {
        ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
            VStack(spacing: 12) {
                ForEach(parts, id: \.self) { part in
                    Image(part.image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: part.size.width * 0.4, height: part.size.height * 0.4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.paper)
            .environment(\.colorScheme, scheme)
        }
    }
    .ignoresSafeArea()
}
