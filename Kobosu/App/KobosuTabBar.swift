//
//  KobosuTabBar.swift
//  Kobosu
//
//  タブバー（COMPONENTS 3/3）。3 タブ＋中央のこぼすボタン（タブバーから少し浮かせる）。
//  選択中は紫の塗り、それ以外は線のアイコン。こぼすボタンは常に 1 つだけで、このグラデーションがタブの画面の 1 か所になる。
//

import SwiftUI

struct KobosuTabBar: View {
    @Binding var selection: MainTab
    let onCompose: () -> Void

    /// タブバーの面の高さ（ホームインジケーターの分は含まない）
    @ScaledMetric(relativeTo: .caption2) private var barHeight: CGFloat = 56

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            tabButton(.listen, title: "きく", systemImage: "bubble.left", identifier: "tab.listen")
            ComposeButton(action: onCompose)
                .frame(maxWidth: .infinity)
            tabButton(.note, title: "ノート", systemImage: "doc.text", identifier: "tab.note")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Palette.card)
                .frame(height: barHeight)
                .shadow(color: Palette.ink.opacity(0.06), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ tab: MainTab, title: LocalizedStringResource, systemImage: String, identifier: String) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 22))
                    .frame(height: 26)
                Text(title)
                    .font(.zenMaruGothic(.bold, size: 10, relativeTo: .caption2))
            }
            .foregroundStyle(isSelected ? Palette.accent : Palette.inkSecondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// こぼすボタン（直径 60pt・グラデーション）。タブバーの中央に、少し浮かせて置く
private struct ComposeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(Palette.gradient, in: Circle())
                    .shadow(color: Palette.accent.opacity(0.3), radius: 8, y: 4)
                Text("こぼす")
                    .font(.zenMaruGothic(.bold, size: 10, relativeTo: .caption2))
                    .foregroundStyle(Palette.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("こぼす"))
        .accessibilityHint(Text("気持ちを書く画面を開きます"))
        .accessibilityIdentifier("tab.compose")
    }
}

#Preview {
    @Previewable @State var selection = MainTab.listen
    VStack {
        Spacer()
        KobosuTabBar(selection: $selection) {}
    }
    .background(Palette.paper)
}
