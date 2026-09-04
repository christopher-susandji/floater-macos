//
//  VintageTimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 28/08/26.
//

import SwiftUI

/// The `vintage` timer variant: like `classic`, but the countdown is rendered
/// as a 5×8 dot-matrix display. Edit mode lives in `TimerView`.
struct VintageTimerView: TimerContentView {
    @State private var isHovered = false
    @State private var isResetButtonHovered = false
    @Namespace private var namespace

    var viewModel: TimerViewModel
    var onDelete: (() -> Void)?
    var onEdit: (() -> Void)?

    init(viewModel: TimerViewModel, onDelete: (() -> Void)? = nil, onEdit: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDelete = onDelete
        self.onEdit = onEdit
    }

    private var theme: VintageTheme {
        if case .vintage(let theme) = viewModel.type { return theme }
        return .standard
    }

    var body: some View {
        ZStack(alignment: .center) {
            Image("VintageTimerBg")

            TickRingView(remaining: viewModel.remaining, theme: .init(ringBase: FloaterColor.gold, ringActive: FloaterColor.gold))

            timerContent
        }
        .frame(minWidth: 220, minHeight: 220)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32.0))
        .animation(.easeInOut, value: viewModel.timerState)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var timerContent: some View {
        VStack(spacing: Sizing.sm) {
            VStack(spacing: Sizing.xs) {
                if viewModel.title.count > .zero {
                    Text(viewModel.title)
                        .foregroundStyle(FloaterColor.gold)
                        .fontWidth(.compressed)
                        .textCase(.uppercase)
                        .kerning(2)
                        .font(.system(size: 16, weight: .light, design: .default))
                }

                timeDisplay
            }

            TimerControls(
                viewModel: viewModel,
                namespace: namespace,
                configuration: .init(
                    transition: .opacity.combined(with: .move(edge: .bottom)),
                    topPadding: Sizing.sm,
                    themed: true,
                    accentColor: viewModel.accentColor,
                    prominentButton: .init(
                        backgroundColor: FloaterColor.vintageBrown,
                        foregroundColor: FloaterColor.vintageDarkBrown,
                        borderColor: theme.palette.accent.color,
                        borderWidth: 2
                    ),
                    secondaryButton: .init(
                        backgroundColor: theme.controls.background,
                        foregroundColor: theme.controls.foreground,
                        borderColor: theme.controls.border,
                        borderWidth: 2
                    ),
                    buttonShadow: true
                ),
                onPlayPause: { viewModel.startPause() },
                onReset: { viewModel.reset() },
                onEdit: { onEdit?() },
                onDelete: { onDelete?() },
                onResetHover: { hovering in
                    if !viewModel.isRunning {
                        isResetButtonHovered = hovering
                    }
                }
            )
        }
        .padding(Sizing.lg)
    }

    private var timeDisplay: some View {
        Group {
            if isResetButtonHovered {
                DotMatrixTimeView(
                    text: viewModel.durationTimeText,
                    color: FloaterColor.gold
                )
            } else {
                DotMatrixTimeView(
                    text: viewModel.timeText,
                    color: FloaterColor.gold
                )
                .geometryGroup()
                .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
            }
        }
        .frame(width: 140, height: 56)
        .transition(.opacity)
    }
}

#Preview {
    VintageTimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5, type: .vintageDefault)))
        .frame(width: 220, height: 220)
}