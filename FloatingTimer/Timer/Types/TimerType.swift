//
//  TimerType.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import Foundation
import SwiftUI

/// The structural design of a timer. Each case carries its own theme type
/// (or none), so a type and its theming are enforced together by the compiler.
enum TimerType: Hashable {
    case classic(theme: ClassicTheme)
    case vintage(theme: VintageTheme)

    /// The default selection when creating a new timer.
    nonisolated static let classicDefault: TimerType = .classic(theme: .standard)
    nonisolated static let vintageDefault: TimerType = .vintage(theme: .standard)

    var name: String {
        switch self {
        case .classic: return "Classic"
        case .vintage: return "Vintage"
        }
    }

    var accentColor: Color {
        switch self {
        case .classic(let theme): return theme.palette.accent.color
        case .vintage(let theme): return theme.palette.accent.color
        }
    }

    var textPrimaryColor: Color {
        switch self {
        case .classic(let theme): return theme.palette.textPrimary
        case .vintage(let theme): return theme.palette.textPrimary
        }
    }

    var textSecondaryColor: Color {
        switch self {
        case .classic(let theme): return theme.palette.textSecondary
        case .vintage(let theme): return theme.palette.textSecondary
        }
    }
}

/// The list of available timer types (each paired with its default theme).
enum TypeCatalog {
    static let all: [TimerType] = [
        .classicDefault,
        .vintageDefault,
    ]
}