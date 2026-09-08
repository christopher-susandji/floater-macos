//
//  BroadcastTimerView.swift
//  Floater
//
//  Created by Christopher Susandji on 07/09/26.
//

import SwiftUI

/// A clean, full-frame version of the timer intended for the live-video
/// broadcast. Unlike the floating panel, this renders on an opaque black
/// background with large, centered type so it reads clearly inside a
/// Keynote slide.
struct BroadcastTimerView: View {
    let viewModel: TimerViewModel

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 16) {
                if !viewModel.title.isEmpty {
                    Text(viewModel.title)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }

                Text(viewModel.timeText)
                    .font(.system(size: 260, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.accentColor)
                    .minimumScaleFactor(0.3)
                    .lineLimit(1)

                if viewModel.timerState == .paused {
                    Text(Constants.paused)
                        .font(.system(size: 36, weight: .semibold))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(48)
        }
    }
}
