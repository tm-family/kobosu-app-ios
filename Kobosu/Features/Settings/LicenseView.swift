//
//  LicenseView.swift
//  Kobosu
//
//  ライセンス表記。同梱している Zen Maru Gothic（SIL Open Font License 1.1）のライセンス文を出す。
//

import SwiftUI

struct LicenseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "Zen Maru Gothic")
                    .font(.kobosuHeadline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: Self.fontLicense)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Palette.inkSecondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .floralBackground()
        .navigationTitle(Text("ライセンス"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 同梱しているライセンス文（Resources/Fonts/ZenMaruGothic-OFL.txt）
    static var fontLicense: String {
        guard let url = Bundle.main.url(forResource: "ZenMaruGothic-OFL", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }
}

#Preview {
    NavigationStack {
        LicenseView()
    }
}
