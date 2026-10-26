//
//  CategorySheet.swift
//  Kobosu
//
//  カテゴリを選ぶシート。投稿画面の「変更」（6 つと未分類）と、投稿完了画面でカテゴリを付けるとき（6 つだけ）に使う。
//  1 つ選ぶとシートを閉じ、選んだカテゴリを onSelect で返す。
//

import SwiftUI

struct CategorySheet: View {
    /// 出す選択肢（並び順もこのとおり）
    let categories: [PostCategory]
    /// 今のカテゴリ。選択肢に無ければ何も選んでいない
    let selection: PostCategory?
    let onSelect: (PostCategory) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("近いものを 1 つえらんでね")
                        .font(.kobosuSubheadline)
                        .foregroundStyle(Palette.inkSecondary)
                    CategoryPicker(selection: chosen, categories: categories)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Palette.paper)
            .navigationTitle(Text("カテゴリ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("閉じる")
                    }
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityIdentifier("category.sheet.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// 選んだら返して閉じる
    private var chosen: Binding<PostCategory?> {
        Binding {
            selection
        } set: { category in
            guard let category else {
                return
            }
            onSelect(category)
            dismiss()
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            CategorySheet(categories: PostCategory.allCases, selection: .partner) { _ in }
        }
}
