//
//  ClassicTheme.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import Foundation
import SwiftUI

/// The palette + typography that style the `classic` timer type.
/// The accent color of a theme. Either the dynamic system accent or a fixed
/// color, so a theme can track the user's System Settings accent.
enum ThemeAccent: Hashable {
    case system
    case fixed(Color)

    var color: Color {
        switch self {
        case .system: return .accentColor
        case .fixed(let color): return color
        }
    }
}

struct ClassicTheme: Identifiable, Hashable {
    let id: UUID
    var name: String
    var palette: Palette
    var typography: Typography

    init(id: UUID = UUID(), name: String, palette: Palette, typography: Typography = .standard) {
        self.id = id
        self.name = name
        self.palette = palette
        self.typography = typography
    }

    struct Palette: Hashable {
        var accent: ThemeAccent
        var textPrimary: Color
        var textSecondary: Color
        var textTertiary: Color
        var ringBase: Color
        var ringActive: Color
    }

    struct Typography: Hashable {
        var countdown: Countdown
        var title: Title

        static let standard = Typography(countdown: .standard, title: .standard)

        struct Countdown: Hashable {
            var size: CGFloat
            var design: FontDesign
            var weight: FontWeight
            var width: FontWidth

            static let standard = Countdown(
                size: 42,
                design: .monospaced,
                weight: .bold,
                width: .standard
            )
        }

        struct Title: Hashable {
            var size: CGFloat
            var weight: FontWeight
            var width: FontWidth

            static let standard = Title(size: 10, weight: .semibold, width: .expanded)
        }
    }
}