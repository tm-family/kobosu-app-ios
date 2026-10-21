//
//  LockWindow.swift
//  Kobosu
//
//  ロック画面と、中身を覆う画面を出す、いちばん上のウインドウ。
//  シート（投稿・共感・通報）や確認のダイアログは RootView より上に出るので、同じ画面の中に重ねるだけでは隠せない。
//  別のウインドウをアラートより上に出し、シートを開いたままロックしても中身が見えない・さわれない・VoiceOver にも読まれないようにする。
//  キーボードはこのウインドウより上に出るので、出すときに入力のフォーカスを外して閉じる。
//

import SwiftUI
import UIKit

final class LockWindow {
    /// ロック中か・覆うかを、ウインドウの中の画面に伝える
    @Observable
    final class State {
        var isCovered = false
    }

    /// RootView が置かれたシーン。iPad で複数のウインドウを開いても、それぞれのシーンに出す
    weak var scene: UIWindowScene?

    private var window: UIWindow?
    private let state = State()

    /// ロック中か、覆うときだけウインドウを出す
    func update(controller: AppLockController, isCovered: Bool) {
        state.isCovered = isCovered
        let isVisible = controller.isLocked || isCovered
        if isVisible, window == nil {
            window = makeWindow(controller: controller)
        }
        guard let window else {
            return
        }
        if isVisible {
            // キーボード（下書きの続きの予測変換を含む）を閉じ、ロック中に見えない画面へ入力できないようにする
            window.windowScene?.windows.forEach { $0.endEditing(true) }
        }
        window.isHidden = !isVisible
        // 下のウインドウ（シートを含む）を VoiceOver に読ませない
        for other in window.windowScene?.windows ?? [] where other !== window {
            other.accessibilityElementsHidden = isVisible
        }
    }

    private func makeWindow(controller: AppLockController) -> UIWindow? {
        guard let scene else {
            return nil
        }
        let window = UIWindow(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: LockOverlayView(controller: controller, state: state))
        host.view.backgroundColor = .clear
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

/// 置かれたビューのシーンを知らせる（LockWindow をそのシーンに出すため）
struct WindowSceneReader: UIViewRepresentable {
    let onChange: (UIWindowScene?) -> Void

    func makeUIView(context: Context) -> SceneReportingView {
        let view = SceneReportingView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ uiView: SceneReportingView, context: Context) {
        uiView.onChange = onChange
    }

    final class SceneReportingView: UIView {
        var onChange: ((UIWindowScene?) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onChange?(window?.windowScene)
        }
    }
}
