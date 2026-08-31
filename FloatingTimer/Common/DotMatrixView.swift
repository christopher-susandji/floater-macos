//
//  DotMatrixView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 28/08/26.
//

import SwiftUI

/// Renders a single character as a 5×8 grid of circles. Lit dots follow the
/// classic 5×8 dot-matrix glyph patterns; unlit dots render dimmed so the
/// full matrix is visible.
struct DotMatrixDigitView: View {
    /// The character to draw. Unknown characters render blank.
    let character: Character
    /// Diameter of each circle.
    var dotSize: CGFloat
    /// Gap between adjacent circles.
    var spacing: CGFloat
    /// Color of lit dots.
    var color: Color = .primary

    private static let columns = 5
    private static let rows = 8

    private static let glyphs: [Character: [String]] = [
        "0": ["01110", "10001", "10001", "10001", "10001", "10001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "10000", "11111"],
        "3": ["01110", "10001", "00001", "01110", "00001", "00001", "10001", "01110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "10001", "01110"],
        "6": ["00110", "01000", "10000", "11110", "10001", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "10001", "01111", "00001", "00010", "01100"]
    ]

    var body: some View {
        if character == ":" {
            VStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
            }
        } else {
            VStack(spacing: spacing) {
                ForEach(0..<Self.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<Self.columns, id: \.self) { column in
                            Circle()
                                .fill(isLit(row: row, column: column) ? color : color.opacity(0.15))
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                }
            }
        }
    }

    private func isLit(row: Int, column: Int) -> Bool {
        guard let pattern = Self.glyphs[character],
              pattern.indices.contains(row) else { return false }
        let line = pattern[row]
        let index = line.index(line.startIndex, offsetBy: column)
        return line[index] == "1"
    }
}

/// Renders a string (e.g. a formatted timer value) as a row of dot-matrix
/// glyphs that scales to fit the space it is given.
struct DotMatrixTimeView: View {
    let text: String
    var color: Color = .primary

    var body: some View {
        GeometryReader { geo in
            let dotSize = Self.dotSize(fitting: geo.size, glyphCount: text.count)
            HStack(spacing: dotSize * 1.6) {
                ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                    DotMatrixDigitView(
                        character: character,
                        dotSize: dotSize,
                        spacing: dotSize * 0.4,
                        color: color
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    /// Glyphs are 5×8 and spacing scales with dot size, so a string of `n`
    /// glyphs is `n * 6.2d + (n - 1) * d` wide and `10.1d` tall. The largest
    /// dot size that satisfies both constraints is used.
    private static func dotSize(fitting size: CGSize, glyphCount: Int) -> CGFloat {
        let count = max(1, glyphCount)
        let glyphWidth: CGFloat = 5 + 4 * 0.3
        let glyphHeight: CGFloat = 8 + 7 * 0.3
        let totalWidthFactor = glyphWidth * CGFloat(count) + CGFloat(count - 1)
        let widthLimit = size.width / totalWidthFactor
        let heightLimit = size.height / glyphHeight
        return min(widthLimit, heightLimit)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 8) {
            ForEach(Array("0123456789"), id: \.self) { digit in
                DotMatrixDigitView(character: digit, dotSize: 8, spacing: 2)
            }
        }
        DotMatrixTimeView(text: "05:23", color: .primary)
            .frame(width: 140, height: 56)
        DotMatrixTimeView(text: "1:02:09", color: .accentColor)
            .frame(width: 140, height: 56)
    }
    .padding()
}
