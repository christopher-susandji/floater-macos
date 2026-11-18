//
//  TimerControlGlyph.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 18/11/26.
//

import SwiftUI

/// The icon inside a timer control button. Shared by the floating panel's row
/// and the timer list's, so both animate symbol swaps the same way while each
/// control view keeps its own sizing.
struct TimerControlGlyph: View {
    var systemName: String
    var frame: CGFloat
    var size: CGFloat = 12
    var padding: CGFloat = 4

    var body: some View {
        Image(systemName: systemName)
            .fontWeight(.black)
            .font(.system(size: size))
            .contentTransition(.symbolEffect(.replace.byLayer))
            .frame(width: frame, height: frame)
            .fixedSize()
            .padding(padding)
    }
}
