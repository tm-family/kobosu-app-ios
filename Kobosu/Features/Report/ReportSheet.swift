//
//  ReportSheet.swift
//  Kobosu
//
//  投稿の通報（デザイン案 想定画面 15）。理由を 1 つ選ぶだけで通報できる。
//  通報しなくても「この投稿を表示しない」でそっと離れられる。通報は匿名で、投稿した人には伝わらない。
//  通報した投稿も、この端末のタイムラインにはもう出さない。
//

import SwiftUI

struct ReportSheet: View {
    let onReport: (ReportReason) async throws -> Void
    let onHide: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason?
    @State private var isWorking = false
    @State private var errorMessage: LocalizedStringResource?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("この投稿について")
                        .font(.kobosuTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("通報は匿名です。投稿した人には伝わりません。")
                        .kobosuMetaLabel()
                }
                VStack(spacing: 0) {
                    ForEach(ReportReason.allCases) { reason in
                        if reason != ReportReason.allCases.first {
                            Divider()
                        }
                        reasonRow(reason)
                    }
                }
                .padding(.horizontal, 16)
                .background(Palette.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                if let errorMessage {
                    Text(errorMessage)
                        .font(.kobosuCaption)
                        .foregroundStyle(Palette.caution)
                }
                VStack(spacing: 8) {
                    Button {
                        Task { await report() }
                    } label: {
                        Text("通報する")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.kobosuSecondary)
                    .disabled(reason == nil || isWorking)
                    .accessibilityIdentifier("report.submit")
                    Button {
                        Task { await hide() }
                    } label: {
                        Text("この投稿を表示しない")
                            .font(.kobosuBody)
                            .foregroundStyle(isWorking ? Palette.disabledInk : Palette.accentDeep)
                            .frame(maxWidth: .infinity, minHeight: KobosuButtonStyle.minimumTapSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                    .accessibilityIdentifier("report.hide")
                }
            }
            .padding(24)
        }
        .background(Palette.card)
        .interactiveDismissDisabled(isWorking)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
    }

    /// 理由を 1 つだけ選ぶ（ラジオボタン）
    private func reasonRow(_ reason: ReportReason) -> some View {
        let isSelected = self.reason == reason
        return Button {
            self.reason = reason
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Palette.accent : Palette.line)
                    .accessibilityHidden(true)
                Text(reason.title)
                    .font(.kobosuBody)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: KobosuButtonStyle.minimumTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("report.reason.\(reason.rawValue)")
    }

    private func report() async {
        guard let reason else {
            return
        }
        await run { try await onReport(reason) }
    }

    private func hide() async {
        await run { try await onHide() }
    }

    /// 通報・非表示ができたらシートを閉じる。できなかったら注意の色で伝え、シートは残す
    private func run(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await action()
            dismiss()
        } catch {
            errorMessage = "できませんでした。少し時間をおいて、もう一度どうぞ。"
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ReportSheet { _ in } onHide: {}
        }
}
