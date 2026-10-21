//
//  LockWindow.swift
//  Kobosu
//
//  ロック画面と、中身を覆う画面を出す、いちばん上のウインドウ。
//  シート（投稿・共感・通報）や確認のダイアログは RootView より上に出るので、同じ画面の中に重ねるだけでは隠せない。
//  別のウインドウをアラートより上に出し、シートを開いたままロックしても中身が見えない・さわれない・VoiceOver にも読まれないようにする。
//

import SwiftUI
import UIKit

final class LockWindow {
    /// ロック中か・覆うかを、ウインドウの中の画面に伝える
    @Observable
    final class State {
        var isCovered = false
    }

    private var window: UIWindow?
    private let state = State()

    /// ロック中か、覆うときだけウインドウを出す
    func update(controller: AppLockController, isCovered: Bool) {
        state.isCovered = isCovered
        let isVisible = controller.isLocked || isCovered
        if isVisible, window == nil {
            window = makeWindow(controller: controller)
        }
        window?.isHidden = !isVisible
    }

    private func makeWindow(controller: AppLockController) -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return nil
        }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: LockOverlayView(controller: controller, state: state))
        host.view.backgroundColor = .clear
        // 下のウインドウ（シートを含む）を VoiceOver に読ませない
        host.view.accessibilityViewIsModal = true
        window.rootViewController = host
        return window
    }
}

/// ウインドウの中の画面。ロック中はロック解除の画面、そうでなければ中身を覆う画面
private struct LockOverlayView: View {
    let controller: AppLockController
    let state: LockWindow.State

    var body: some View {
        if controller.isLocked {
            LockScreenView(controller: controller)
        } else if state.isCovered {
            PrivacyCoverView()
        }
    }
}
