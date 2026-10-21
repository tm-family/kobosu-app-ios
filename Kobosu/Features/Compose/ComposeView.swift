//
//  ComposeView.swift
//  Kobosu
//
//  タブバー中央の「こぼす」ボタンから開く投稿画面（デザイン案 SCREEN 02）。
//  本文（最大 400 字）・書き始めのヒント・カテゴリを 1 つ選ぶ・24 時間で消えることを伝える。
//  ナビゲーションバーは左が取り消し・中央がタイトル・右が投稿（COMPONENTS 3/3）。
//  書いている途中の本文とカテゴリは端末に下書きとして残し、キャンセルや引いて閉じても続きから書ける。
//  公開範囲は今回「みんなに共有」だけ、消える期間は 24 時間だけなので、選ぶ UI は出さない。
//  「投稿」を押すと伏せ字の候補を探し、見つかったら伏せ字の確認（MaskingReviewView）に進む。
//

import SwiftUI

struct ComposeView: View {
    /// 投稿できたときに呼ぶ
    let onPosted: (Post) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model: ComposeViewModel

    init(repository: any PostRepository, drafts: any ComposeDraftStore, onPosted: @escaping (Post) -> Void) {
        self.onPosted = onPosted
        _model = State(initialValue: ComposeViewModel(repository: repository, drafts: drafts))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        PostTextArea(text: $model.body, limit: Post.maxBodyLength, count: model.bodyLength)
                            .disabled(model.isBusy)
                        if model.isOverLimit {
                            note("\(Post.maxBodyLength) 文字までにすると、投稿できます")
                        }
                        hint
                    }
                    categorySection
                        .disabled(model.isBusy)
                    lifetimeSection
                    if model.state == .failed {
                        note("投稿できませんでした。時間をおいて、もう一度ためせます。")
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.paper)
            .navigationTitle(Text("こぼす"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("キャンセル")
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("compose.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        Text("投稿")
                    }
                    .buttonStyle(.kobosuPrimarySmall)
                    .disabled(!model.canSubmit)
                    .accessibilityIdentifier("compose.submit")
                }
            }
            // 送っている途中は閉じさせない（送れたかどうか分からなくなるため）
            .interactiveDismissDisabled(model.isBusy)
            .navigationDestination(isPresented: isReviewing) {
                MaskingReviewView(model: model) { post in
                    finish(post)
                }
            }
            .onChange(of: model.body) {
                model.saveDraft()
            }
            .onChange(of: model.category) {
                model.saveDraft()
            }
        }
    }

    /// 書き始めのヒント。相手を責める文より、自分の気持ちを書くほうがやさしい反応が集まる
    private var hint: some View {
        Text("相手より「自分の気持ち」を書くと届きやすいよ")
            .font(.kobosuSubheadline)
            .foregroundStyle(Palette.accentDeep)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Palette.lavender, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("カテゴリ")
            CategoryPicker(selection: $model.category)
            if model.category == nil, model.bodyLength > 0 {
                Text("カテゴリを 1 つえらぶと、投稿できます")
                    .kobosuMetaLabel()
            }
        }
    }

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("消えるまで")
            Label {
                Text("24時間たつと、自動で消えます")
                    .font(.kobosuBody)
                    .foregroundStyle(Palette.ink)
            } icon: {
                Image(systemName: "clock")
                    .foregroundStyle(Palette.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kobosuCard(padding: 14)
            .accessibilityElement(children: .combine)
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
    }

    /// 伏せ字の確認を出しているか。戻る（自分で書き直す）と確認を閉じる
    private var isReviewing: Binding<Bool> {
        Binding {
            model.review != nil
        } set: { isPresented in
            if !isPresented {
                model.review = nil
            }
        }
    }

    private func submit() async {
        guard let post = await model.submit() else {
            return
        }
        finish(post)
    }

    private func finish(_ post: Post) {
        onPosted(post)
        dismiss()
    }
}

#Preview {
    ComposeView(repository: InMemoryPostRepository.preview(), drafts: InMemoryComposeDraftStore()) { _ in }
}

#Preview("下書きあり") {
    ComposeView(
        repository: InMemoryPostRepository.preview(),
        drafts: InMemoryComposeDraftStore(
            draft: ComposeDraft(body: "「手伝おうか」って言われるたびにモヤっとする。二人の家のことなのに。", category: .partner)
        )
    ) { _ in }
}
