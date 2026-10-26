//
//  CategoryEstimatorTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct CategoryEstimatorTests {
    /// カテゴリごとの典型の文
    @Test(arguments: [
        ("帰省のたびに義母から「まだなの？」と聞かれる。", PostCategory.inLaws),
        ("同居の姑が、台所の配置を勝手に変える。", .inLaws),
        ("夫に話しかけても、スマホを見たまま返事がない。", .partner),
        ("旦那の言い方に、今日もモヤっとした。", .partner),
        ("寝かしつけに 2 時間。夜泣きでまた起こされた。", .parenting),
        ("保育園のお迎えに間に合わなくて、子どもが泣いていた。", .parenting),
        ("今日も一人で洗い物と洗濯と掃除をした。", .housework),
        ("家事の分担を話し合おうとしても、聞いてもらえない。", .housework),
        ("家計がきつくて、今月も貯金ができなかった。", .money),
        ("給料日前なのに、出費が続く。", .money)
    ])
    func estimatesTypicalText(text: String, expected: PostCategory) {
        #expect(CategoryEstimator.estimate(text) == expected)
    }

    /// デザイン案 6 枚目の例文は、モックのとおり「パートナー」になる
    /// （「手伝」（家事分担）と「二人」（パートナー）が 1 つずつで同じ数なので、case の順でパートナーを選ぶ）
    @Test
    func designSampleIsPartner() {
        let text = "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。言い返す元気もなくて、今日も黙る。"
        #expect(CategoryEstimator.estimate(text) == .partner)
    }

    /// どの言葉も出てこない文・空文字は推定しない（その他・未分類にはしない）
    @Test(arguments: ["", " \n", "今日はなんだか疲れた。", "ほんとは「ありがとう」って、ひとこと言ってほしかっただけ。"])
    func returnsNilWithoutKeywords(text: String) {
        #expect(CategoryEstimator.estimate(text) == nil)
    }

    /// 多く出てくるカテゴリを選ぶ
    @Test
    func picksCategoryWithMostKeywords() {
        // 子育て: 子ども・保育園・寝かしつけ（3）、パートナー: 夫（1）
        let text = "夫は子どもの保育園の準備も寝かしつけもしない。"
        #expect(CategoryEstimator.scores(for: text)[.parenting] == 3)
        #expect(CategoryEstimator.scores(for: text)[.partner] == 1)
        #expect(CategoryEstimator.estimate(text) == .parenting)
    }

    /// 同じ数のときは PostCategory の case の順（義理の親 → パートナー → 子育て → 家事分担 → お金）で選ぶ
    @Test
    func tieGoesToEarlierCategory() {
        #expect(CategoryEstimator.estimate("義母とお金の話") == .inLaws)
        #expect(CategoryEstimator.estimate("洗濯とローン") == .housework)
        #expect(CategoryEstimator.estimate("ローンと洗濯") == .housework)
    }

    /// 同じ言葉が何度も出てきたら、その数だけ数える
    @Test
    func countsRepeatedKeywords() {
        #expect(CategoryEstimator.scores(for: "掃除、掃除、また掃除。")[.housework] == 3)
    }

    /// ひらがな／カタカナ、全角／半角の違いは同じ言葉として数える
    @Test(arguments: [
        ("パートナーが", PostCategory.partner),
        ("ぱーとなーが", .partner),
        ("ﾊﾟｰﾄﾅｰが", .partner),
        ("ダンナが", .partner),
        ("コドモが", .parenting),
        ("ｺﾞﾐ出し", .housework)
    ])
    func foldsKanaAndWidth(text: String, expected: PostCategory) {
        #expect(CategoryEstimator.estimate(text) == expected)
    }

    /// 「大丈夫」「工夫」の「夫」はパートナーとして数えない
    @Test(arguments: ["大丈夫、なんとかなる。", "工夫してみたけど、だめだった。"])
    func ignoresPhrasesContainingKeywords(text: String) {
        #expect(CategoryEstimator.estimate(text) == nil)
    }

    /// 推定するのは 5 つだけ。その他・未分類の言葉の一覧は持たない
    @Test
    func estimatesOnlyFiveCategories() {
        #expect(Set(CategoryEstimator.keywords.keys) == [.inLaws, .partner, .parenting, .housework, .money])
        for words in CategoryEstimator.keywords.values {
            #expect(!words.isEmpty)
            #expect(!words.contains(""))
        }
    }

    /// 1 つの言葉が 2 つのカテゴリに入っていない（どちらのカテゴリか決められなくなるため）
    @Test
    func keywordsDoNotOverlapAcrossCategories() {
        let all = CategoryEstimator.keywords.values.flatMap { $0.map(CategoryEstimator.normalized) }
        #expect(all.count == Set(all).count)
    }
}
