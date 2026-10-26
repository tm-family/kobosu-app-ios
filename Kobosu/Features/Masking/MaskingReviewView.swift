//
//  MaskingReviewView.swift
//  Kobosu
//
//  投稿の前の伏せ字の確認（デザイン案 SAFETY「書いているとき」）。身バレにつながりそうな言葉を注意の色で示し、
//  候補ごとに伏せるか・そのままにするかを本人が選ぶ（最初はすべて伏せる）。伏せ字にした本文をプレビューで見せてから投稿する。
//  検知は提案にとどめるので、すべて「そのまま」にしても投稿できる。
//

import SwiftUI

struct MaskingReviewView: View {
    let model: ComposeViewModel
    /// 投稿できたときに呼ぶ
    let onPosted: (Post) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if let review = model.review {
                VStack(alignment: .leading, spacing: 20) {
                    highlightedBody(review)
                    warning(review)
                    candidateList(review)
                    preview(review)
                    actions(review)
                }
                .padding(16)
            }
        }
        .background(Palette.paper)
        .navigationTitle(Text("伏せ字の確認"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.isBusy)
    }

    /// 書いた本文。伏せる言葉を注意の色で示す
    private func highlightedBody(_ review: MaskingReview) -> some View {
        Text(highlighted(review))
            .font(.kobosuBody)
            .foregroundStyle(Palette.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .kobosuCard()
    }

    private func highlighted(_ review: MaskingReview) -> AttributedString {
        var attributed = AttributedString(review.text)
        for (index, candidate) in review.candidates.enumerated() where review.isMasked(at: index) {
            guard let range = Range(NSRange(candidate.range, in: review.text), in: attributed) else {
                continue
            }
            attributed[range].foregroundColor = Palette.caution
            attributed[range].underlineStyle = .single
        }
        return attributed
    }

    private func warning(_ review: MaskingReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("身バレにつながる言葉があります")
                    .font(.kobosuSubheadline)
                    .foregroundStyle(Palette.ink)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Palette.caution)
            }
            Text("\(foundList(review))を見つけました。伏せ字にすれば、このまま投稿できます。")
                .font(.kobosuCaption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.caution, lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
    }

    /// 「人の名前「田中」、電話番号「090-…」」。かぎかっこと区切りは表示の言語に合わせる
    private func foundList(_ review: MaskingReview) -> String {
        let locale = Locale.current
        let open = locale.quotationBeginDelimiter ?? "「"
        let close = locale.quotationEndDelimiter ?? "」"
        let items = review.candidates.map { "\(String(localized: $0.kind.title))\(open)\($0.text)\(close)" }
        return ListFormatter.localizedString(byJoining: items)
    }

    private func candidateList(_ review: MaskingReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("伏せる言葉")
            VStack(spacing: 0) {
                ForEach(Array(review.candidates.enumerated()), id: \.offset) { index, candidate in
                    if index > 0 {
                        Divider()
                    }
                    Toggle(isOn: maskBinding(at: index)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.kind.title)
                                .kobosuMetaLabel()
                            Text(candidate.text)
                                .font(.kobosuBody)
                                .foregroundStyle(Palette.ink)
                        }
                    }
                    .tint(Palette.accent)
                    .frame(minHeight: KobosuButtonStyle.minimumTapSize)
                    .padding(.vertical, 6)
                    .disabled(model.isBusy)
                    .accessibilityLabel(Text("\(String(localized: candidate.kind.title))「\(candidate.text)」を伏せる"))
                    .accessibilityIdentifier("masking.toggle.\(index)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("オフにした言葉は、そのまま投稿されます")
                .kobosuMetaLabel()
        }
    }

    private func maskBinding(at index: Int) -> Binding<Bool> {
        Binding {
            model.review?.isMasked(at: index) ?? false
        } set: { masked in
            model.setMasked(masked, at: index)
        }
    }

    private func preview(_ review: MaskingReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("伏せ字プレビュー")
            Text(review.result)
                .font(.kobosuBody)
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Palette.segmentSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityIdentifier("masking.preview")
        }
    }

    private func actions(_ review: MaskingReview) -> some View {
        VStack(spacing: 12) {
            if review.isOverLimit {
                note("伏せ字にすると \(Post.maxBodyLength) 文字をこえます。書き直すと投稿できます")
            }
            if model.state == .failed {
                note("投稿できませんでした。時間をおいて、もう一度ためせます。")
            }
            Button {
                Task {
                    if let post = await model.submitReview() {
                        onPosted(post)
                    }
                }
            } label: {
                Text("この内容で投稿する")
            }
            .buttonStyle(.kobosuPrimary)
            .disabled(!model.canSubmitReview)
            .accessibilityIdentifier("masking.submit")
            Button {
                dismiss()
            } label: {
                Text("自分で書き直す")
            }
            .buttonStyle(.kobosuOutline)
            .disabled(model.isBusy)
            .accessibilityIdentifier("masking.rewrite")
        }
    }

    private func sectionTitle(_ title: LocalizedStringResource) -> some View {
        Text(title)
            .font(.zenMaruGothic(.bold, size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    /// 投稿できないわけを伝える（注意の色。赤は使わない）
    private func note(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.kobosuCaption)
            .foregroundStyle(Palette.caution)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let model = ComposeViewModel(
        repository: InMemoryPostRepository.preview(),
        drafts: InMemoryComposeDraftStore(
            draft: ComposeDraft(body: "義母の山田さんが、また勝手に家に来て冷蔵庫を整理していった。電話は 090-1234-5678。", category: .inLaws)
        ),
        lastCategories: InMemoryLastCategoryStore()
    )
    return NavigationStack {
        MaskingReviewView(model: model) { _ in }
    }
    .task {
        _ = await model.submit()
    }
}
