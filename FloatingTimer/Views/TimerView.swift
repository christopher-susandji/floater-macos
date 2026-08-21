//
//  TimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

struct TimerView: View {
    @State private var viewModel: TimerViewModel
    @State private var isHovered = false
    @State private var editMode = false
    @State private var isResetButtonHovered = false
    @Namespace private var namespace
    
    let minutes: [TimeInterval] = [60, 120, 180, 300, 600, 900, 1800, 3600]
    let columnLayout = Array(repeating: GridItem(), count: 2)
    var onDelete: (() -> Void)?
    
    init(viewModel: TimerViewModel, onDelete: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onDelete = onDelete
    }
    
    var body: some View {
        Group {
            ZStack(alignment: .center) {
                TickRingView(remaining: viewModel.remaining)
                
                if !editMode {
                    timerContent
                } else {
                    editModeContent
                }
            }
            .frame(minWidth: 220, minHeight: 220)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32.0))
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
                        .foregroundStyle(.secondary)
                        .fontWidth(.expanded)
                        .textCase(.uppercase)
                        .fontWeight(.semibold)
                        .font(.caption)
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
                        .foregroundStyle(.tertiary)
                        .fontWidth(.expanded)
                        .textCase(.uppercase)
                        .fontWeight(.semibold)
                        .font(.caption)
                }
            }
        }
        .padding(Sizing.lg)
    }
    
    private var timeDisplay: some View {
        Group {
            if isResetButtonHovered {
                Text(viewModel.durationTimeText)
                    .foregroundStyle(.primary)
            } else {
                Text(viewModel.timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .foregroundStyle(viewModel.timerState == .paused ? .secondary : .primary)
                    .geometryGroup()
                    .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
            }
        }
        .font(.system(size: 42, weight: .bold, design: .monospaced))
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
    TimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}
