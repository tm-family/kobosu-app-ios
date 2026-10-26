//
//  PromiseView.swift
//  Kobosu
//
//  初回起動の「やさしさの約束」（デザイン案 06）。規約の前に、場のルールを 4 行で。同意してから使い始める。
//

import SwiftUI

struct PromiseView: View {
    let onAgree: () -> Void

    @State private var isChecked = false

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("やさしさの約束")
                        .font(.kobosuLargeTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 32)
                    Text("ここを、安心できる場所にするために。")
                        .kobosuMetaLabel()
                    ForEach(PromiseRule.allCases) { rule in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(verbatim: "#\(rule.rawValue)")
                                .roundedFont(size: 13, weight: .bold, relativeTo: .callout)
                                .foregroundStyle(Palette.accent)
                                .accessibilityHidden(true)
                            Text(rule.title)
                                .font(.zenMaruGothic(.bold, size: 15, relativeTo: .body))
                                .foregroundStyle(Palette.ink)
                        }
                        .kobosuCard(padding: 16)
                    }
                    Toggle(isOn: $isChecked) {
                        Text("約束を守って使います")
                            .font(.kobosuBody)
                            .foregroundStyle(Palette.ink)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                    .accessibilityIdentifier("onboarding.promiseCheck")
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            }
            Button(action: onAgree) {
                Text("同意してはじめる")
            }
            .buttonStyle(.kobosuPrimary)
            .disabled(!isChecked)
            .accessibilityIdentifier("onboarding.agree")
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .floralBackground()
    }
}

/// 四角のチェックボックス。オンのときは紫
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(configuration.isOn ? Palette.accent : Palette.inkSecondary)
                    .accessibilityHidden(true)
                configuration.label
            }
            .frame(minHeight: KobosuButtonStyle.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? Text("チェックあり") : Text("チェックなし"))
    }
}

#Preview {
    PromiseView {}
}
