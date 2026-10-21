//
//  ReportDocumentTests.swift
//  KobosuTests
//

import Foundation
@testable import Kobosu
import Testing

struct ReportDocumentTests {
    /// 通報の文書の中身には、通報した人が分かる値を置かない（uid は文書 ID だけ）
    @Test
    func reportFieldsHaveOnlyReason() {
        let fields = ReportDocument.reportFields(reason: .harassment)
        #expect(fields.count == 1)
        #expect(fields[ReportDocument.Field.reason] as? String == "harassment")
    }

    @Test
    func reportCountDefaultsToZero() {
        #expect(ReportDocument.reportCount(inPost: [:]) == 0)
        #expect(ReportDocument.reportCount(inPost: [ReportDocument.Field.reportCount: NSNumber(value: 2)]) == 2)
        #expect(ReportDocument.reportCount(inPost: [ReportDocument.Field.reportCount: "3"]) == 0)
    }

    /// しきい値の人数から、タイムラインに出さない
    @Test
    func autoHiddenFromThreshold() {
        let threshold = ReportPolicy.autoHideThreshold
        #expect(!ReportDocument.isAutoHidden(post: [:], threshold: threshold))
        #expect(!ReportDocument.isAutoHidden(post: [ReportDocument.Field.reportCount: threshold - 1], threshold: threshold))
        #expect(ReportDocument.isAutoHidden(post: [ReportDocument.Field.reportCount: threshold], threshold: threshold))
        #expect(ReportDocument.isAutoHidden(post: [ReportDocument.Field.reportCount: threshold + 1], threshold: threshold))
    }
}
