//
//  ClassicTimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import SwiftUI

/// The `classic` timer variant: rounded glass panel with tick ring, hover
/// controls and preset editing. Fully driven by its `ClassicTheme`.
struct ClassicTimerView: TimerContentView {
    @State private var isHovered = false
    @State private var editMode = false
    @State private var isResetButtonHovered = false
    @Namespace private var namespace

    var viewModel: TimerViewModel
    var onDelete: (() -> Void)?

    init(viewModel: TimerViewModel, onDelete: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDelete = onDelete
    }

    private var theme: ClassicTheme {
        if case .classic(let theme) = viewModel.type { return theme }
        return .standard
    }

    let minutes: [TimeInterval] = [60, 120, 180, 300, 600, 900, 1800, 3600]
    let columnLayout = Array(repeating: GridItem(), count: 2)

    var body: some View {
        Group {
            ZStack(alignment: .center) {
                TickRingView(remaining: viewModel.remaining, theme: .init(
                    ringBase: theme.palette.ringBase,
                    ringActive: theme.palette.ringActive))

                if !editMode {
                    timerContent
                } else {
                    editModeContent
                }
            }
            .frame(minWidth: 220, minHeight: 220)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32.0))
            .animation(.easeInOut, value: viewModel.timerState)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onChange(of: viewModel.editRequestToken) { _, newValue in
                withAnimation(.easeInOut(duration: 0.15)) {
                    editMode = newValue > 0
                }
            }
        }
    }

    private var timerContent: some View {
        VStack(spacing: Sizing.sm) {
            VStack(spacing: Sizing.xs) {
                if viewModel.title.count > .zero {
                    Text(viewModel.title)
                        .foregroundStyle(theme.palette.textSecondary)
                        .fontWidth(theme.typography.title.width.swiftUI)
                        .textCase(.uppercase)
                        .fontWeight(theme.typography.title.weight.swiftUI)
                        .font(.system(size: theme.typography.title.size, weight: .regular, design: .default))
                }

                timeDisplay
            }

            if isHovered {
                TimerControls(
                    viewModel: viewModel,
                    namespace: namespace,
                    configuration: .init(
                        transition: .opacity.combined(with: .move(edge: .bottom)),
                        topPadding: Sizing.sm
                    ),
                    onPlayPause: { viewModel.startPause() },
                    onReset: { viewModel.reset() },
                    onEdit: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            editMode.toggle()
                        }
                    },
                    onDelete: { onDelete?() },
                    onResetHover: { hovering in
                        if !viewModel.isRunning {
                            isResetButtonHovered = hovering
                        }
                    }
                )
            } else {
                if viewModel.timerState == .paused {
                    Text(Constants.paused)
                        .foregroundStyle(theme.palette.textTertiary)
                        .fontWidth(theme.typography.title.width.swiftUI)
                        .textCase(.uppercase)
                        .fontWeight(theme.typography.title.weight.swiftUI)
                        .font(.system(size: theme.typography.title.size, weight: .regular, design: .default))
                }
            }
        }
        .padding(Sizing.lg)
    }

    private var timeDisplay: some View {
        Group {
            if isResetButtonHovered {
                Text(viewModel.durationTimeText)
                    .foregroundStyle(theme.palette.textPrimary)
            } else {
                Text(viewModel.timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(viewModel.timerState == .paused ? theme.palette.textSecondary : theme.palette.textPrimary)
                    .geometryGroup()
                    .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
            }
        }
        .font(.system(
            size: theme.typography.countdown.size,
            weight: theme.typography.countdown.weight.swiftUI,
            design: theme.typography.countdown.design.swiftUI
        ))
        .fontWidth(theme.typography.countdown.width.swiftUI)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 140)
        .transition(.opacity)
    }

    private var editModeContent: some View {
        VStack {
            HStack(alignment: .center) {
                Text(Constants.changeTimerButton)
                    .textCase(.uppercase)
                    .font(.caption)
                    .fontWeight(.medium)
                    .fontWidth(.expanded)
                    .foregroundStyle(theme.palette.textSecondary)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editMode.toggle()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.bold)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
                .padding(.bottom, Sizing.sm)
            }

            ScrollView(.vertical) {
                LazyVGrid(columns: columnLayout, pinnedViews: [.sectionHeaders]) {
                    ForEach(minutes, id: \.description) { preset in
                        TimerPresetCell(preset) { time in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                editMode.toggle()
                            }
                            viewModel.updateTimer(time: time)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(4)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .frame(width: 160, height: 160)
    }
}

#Preview {
    ClassicTimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}
