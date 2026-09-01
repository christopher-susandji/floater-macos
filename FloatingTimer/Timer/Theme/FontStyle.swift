//
//  FontStyle.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import SwiftUI

enum FontDesign: String, Codable, CaseIterable {
    case `default`, rounded, monospaced, serif

    var swiftUI: Font.Design {
        switch self {
        case .default: return .default
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        case .serif: return .serif
        }
    }
}

enum FontWeight: String, Codable, CaseIterable {
    case regular, medium, semibold, bold, heavy, black

    var swiftUI: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

enum FontWidth: String, Codable, CaseIterable {
    case standard, expanded, condensed, compressed

    var swiftUI: Font.Width {
        switch self {
        case .standard: return .standard
        case .expanded: return .expanded
        case .condensed: return .condensed
        case .compressed: return .compressed
        }
    }
}