//
//  OnboardingView.swift
//  Kobosu
//
//  初回起動の流れ。ようこそ → やさしさの約束。同意したら onFinish を呼ぶ。
//  アプリロックの設定（デザイン案 07）はタスク 15 で、この流れの最後に足す。
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var step = Step.welcome

    private enum Step {
        case welcome
        case promise
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomeView {
                    withAnimation {
                        step = .promise
                    }
                }
            case .promise:
                PromiseView(onAgree: onFinish)
                    .transition(.move(edge: .trailing))
            }
        }
    }
}

#Preview {
    OnboardingView {}
}
