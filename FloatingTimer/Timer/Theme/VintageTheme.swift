//
//  VintageTheme.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 28/08/26.
//

import Foundation
import SwiftUI

/// The palette + typography + control styling that drive the `vintage` timer
/// type.
struct VintageTheme: Identifiable, Hashable {
    let id: UUID
    var name: String
    var palette: Palette
    var typography: Typography
    /// Styling for the non-prominent control buttons.
    var controls: Controls

    init(id: UUID = UUID(), name: String, palette: Palette, typography: Typography = .standard, controls: Controls) {
        self.id = id
        self.name = name
        self.palette = palette
        self.typography = typography
        self.controls = controls
    }

    typealias Palette = ClassicTheme.Palette
    typealias Typography = ClassicTheme.Typography

    struct Controls: Hashable {
        var border: Color
        var background: Color
        var foreground: Color
    }
}

extension VintageTheme {
    /// The default vintage look: dark brown controls with red-brown borders,
    /// gold accents on a warm cream backdrop.
    static let standard = VintageTheme(
        name: "Vintage",
        palette: Palette(
            accent: .fixed(Color(#colorLiteral(red: 0.835, green: 0.635, blue: 0.29, alpha: 1))),
            textPrimary: Color(#colorLiteral(red: 0.95, green: 0.90, blue: 0.78, alpha: 1)),
            textSecondary: Color(#colorLiteral(red: 0.80, green: 0.71, blue: 0.55, alpha: 1)),
            textTertiary: Color(#colorLiteral(red: 0.60, green: 0.52, blue: 0.42, alpha: 1)),
            ringBase: Color(#colorLiteral(red: 0.612, green: 0.416, blue: 0.184, alpha: 1)),
            ringActive: Color(#colorLiteral(red: 0.835, green: 0.635, blue: 0.29, alpha: 1))
        ),
        controls: Controls(
            border: Color(#colorLiteral(red: 0.557, green: 0.275, blue: 0.192, alpha: 1)),
            background: Color(#colorLiteral(red: 0.243, green: 0.169, blue: 0.129, alpha: 1)),
            foreground: Color(#colorLiteral(red: 0.835, green: 0.635, blue: 0.29, alpha: 1))
        )
    )
}