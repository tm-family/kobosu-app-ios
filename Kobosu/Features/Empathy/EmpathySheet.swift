//
//  EmpathySheet.swift
//  Kobosu
//
//  投稿をタップすると開く「気持ちを送る」ハーフシート（デザイン案 SCREEN 03）。
//  返せるのは共感スタンプだけで、コメント欄は置かない（ひとことは次の段階）。
//  スタンプはワンタップで送り、ふわっと浮く動きと軽いハプティクスを 1 回返す。
//

import SwiftUI

struct EmpathySheet: View {
    let post: Post
    let sentStamps: Set<EmpathyStamp>
    let onSend: (EmpathyStamp) async throws -> Void

    @State private var sending: EmpathyStamp?
    @State private var floating: EmpathyStamp?
    @State private var sentCount = 0
    @State private var errorMessage: LocalizedStringResource?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("気持ちを送る")
                        .font(.kobosuTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("送れるのは共感のスタンプだけです")
                        .kobosuMetaLabel()
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(EmpathyStamp.allCases) { stamp in
                        stampButton(stamp)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.kobosuCaption)
                        .foregroundStyle(Palette.caution)
                }
            }
            .padding(24)
        }
        .background(Palette.card)
        .sensoryFeedback(.impact(weight: .light), trigger: sentCount)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
    }

    private func stampButton(_ stamp: EmpathyStamp) -> some View {
        let isSent = sentStamps.contains(stamp)
        return Button {
            Task { await send(stamp) }
        } label: {
            BigStampLabel(stamp: stamp, isSent: isSent)
                .overlay {
                    if floating == stamp {
                        FloatingStamp(stamp: stamp)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isSent || sending != nil)
        .accessibilityLabel(Text(stamp.title))
        .accessibilityValue(isSent ? Text("送りました") : Text(verbatim: ""))
        .accessibilityIdentifier("empathy.\(stamp.rawValue)")
    }

    private func send(_ stamp: EmpathyStamp) async {
        sending = stamp
        errorMessage = nil
        defer { sending = nil }
        do {
            try await onSend(stamp)
            sentCount += 1
            if !reduceMotion {
                floating = stamp
                try? await Task.sleep(for: .milliseconds(900))
                if floating == stamp {
                    floating = nil
                }
            }
        } catch PostRepositoryError.postNotFound {
            errorMessage = "この投稿は、もう消えています。"
        } catch {
            errorMessage = "送れませんでした。少し時間をおいて、もう一度どうぞ。"
        }
    }
}

/// 共感スタンプ（大）（COMPONENTS 2/3）。159×68pt・角丸 18pt。送った後は紫の線と面
private struct BigStampLabel: View {
    let stamp: EmpathyStamp
    let isSent: Bool

    @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 68

    var body: some View {
        Text(stamp.title)
            .font(.kobosuHeadline)
            .foregroundStyle(isSent ? Palette.accentDeep : Palette.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSent ? Palette.lavender : Palette.card)
                    .stroke(isSent ? Palette.accent : Palette.line, lineWidth: isSent ? 2 : 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// 送ったときに、スタンプの文字がふわっと浮いて消える
private struct FloatingStamp: View {
    let stamp: EmpathyStamp

    @State private var isRising = false

    var body: some View {
        Text(stamp.title)
            .font(.kobosuHeadline)
            .foregroundStyle(Palette.accent)
            .offset(y: isRising ? -56 : 0)
            .scaleEffect(isRising ? 1.15 : 1)
            .opacity(isRising ? 0 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    isRising = true
                }
            }
    }
}

#Preview {
    @Previewable @State var sent: Set<EmpathyStamp> = [.sameHere]
    Color.clear
        .sheet(isPresented: .constant(true)) {
            EmpathySheet(
                post: Post(id: "a", body: "同居の義母が、台所の配置を勝手に変える。", category: .inLaws, createdAt: .now),
                sentStamps: sent
            ) { stamp in
                sent.insert(stamp)
            }
        }
}
