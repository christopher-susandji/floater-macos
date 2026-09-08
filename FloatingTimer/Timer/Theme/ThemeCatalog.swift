//
//  ThemeCatalog.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import Foundation
import SwiftUI

enum ThemeCatalog {
    /// Presets for the `classic` timer type, shown in the theme picker.
    static let classicPresets: [ClassicTheme] = [
        .standard,
        .ocean,
        .ember,
    ]

    /// Presets for the `vintage` timer type, shown in the theme picker.
    static let vintagePresets: [VintageTheme] = [
        .standard,
    ]
}

extension ClassicTheme {
    /// The default look: white text, white ring, system accent color.
    static let standard = ClassicTheme(
        name: "Classic",
        palette: Palette(
            accent: .system,
            textPrimary: Color(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)),
            textSecondary: Color(#colorLiteral(red: 0.80, green: 0.80, blue: 0.82, alpha: 1)),
            textTertiary: Color(#colorLiteral(red: 0.60, green: 0.60, blue: 0.63, alpha: 1)),
            ringBase: Color(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)),
            ringActive: Color(#colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1))
        )
    )

    static let ocean = ClassicTheme(
        name: "Ocean",
        palette: Palette(
            accent: .fixed(Color(#colorLiteral(red: 0.0, green: 0.62, blue: 0.95, alpha: 1))),
            textPrimary: Color(#colorLiteral(red: 0.90, green: 0.96, blue: 1.0, alpha: 1)),
            textSecondary: Color(#colorLiteral(red: 0.68, green: 0.79, blue: 0.90, alpha: 1)),
            textTertiary: Color(#colorLiteral(red: 0.52, green: 0.64, blue: 0.76, alpha: 1)),
            ringBase: Color(#colorLiteral(red: 0.52, green: 0.64, blue: 0.76, alpha: 1)),
            ringActive: Color(#colorLiteral(red: 0.20, green: 0.82, blue: 1.0, alpha: 1))
        )
    )

    static let ember = ClassicTheme(
        name: "Ember",
        palette: Palette(
            accent: .fixed(Color(#colorLiteral(red: 1.0, green: 0.60, blue: 0.10, alpha: 1))),
            textPrimary: Color(#colorLiteral(red: 1.0, green: 0.95, blue: 0.90, alpha: 1)),
            textSecondary: Color(#colorLiteral(red: 0.90, green: 0.80, blue: 0.70, alpha: 1)),
            textTertiary: Color(#colorLiteral(red: 0.75, green: 0.62, blue: 0.50, alpha: 1)),
            ringBase: Color(#colorLiteral(red: 0.75, green: 0.62, blue: 0.50, alpha: 1)),
            ringActive: Color(#colorLiteral(red: 1.0, green: 0.72, blue: 0.30, alpha: 1))
        )
    )
}
