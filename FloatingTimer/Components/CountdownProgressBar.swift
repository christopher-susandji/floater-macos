//
//  CountdownProgressBar.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 04/08/26.
//

import SwiftUI

struct CountdownProgressBar: View {
    var cornerRadius: CGFloat
    var progress: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    Color.black.opacity(0.2),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width:220, height: 220)
            
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    Color.primary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width:160, height: 160)
        }
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 10000)))
        .frame(width: 220, height: 220)
}
