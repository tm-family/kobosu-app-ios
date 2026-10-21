//
//  RemainingTime.swift
//  Kobosu
//
//  投稿が消えるまでの残り時間の表し方（「残り 22時間」「残り 45分」）。
//  1 時間以上は時間の切り捨て、1 時間未満は分の切り上げ（0 分とは出さない）。
//

import Foundation

nonisolated enum RemainingTime: Equatable, Sendable {
    case hours(Int)
    case minutes(Int)

    init(_ interval: TimeInterval) {
        let seconds = max(interval, 0)
        if seconds >= 60 * 60 {
            self = .hours(Int(seconds / (60 * 60)))
        } else {
            self = .minutes(max(Int((seconds / 60).rounded(.up)), 1))
        }
    }

    var text: LocalizedStringResource {
        switch self {
        case .hours(let hours):
            "残り \(hours)時間"
        case .minutes(let minutes):
            "残り \(minutes)分"
        }
    }
}
