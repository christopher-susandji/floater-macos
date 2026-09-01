//
//  VintageTimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 28/08/26.
//

import SwiftUI

/// The `vintage` timer variant: like `classic`, but the countdown is rendered
/// as a 5×8 dot-matrix display. Fully driven by its `ClassicTheme`.
struct VintageTimerView: TimerContentView {
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
    
    private var theme: VintageTheme {
        if case .vintage(let theme) = viewModel.type { return theme }
        return .standard
    }
    
    let minutes: [TimeInterval] = [60, 120, 180, 300, 600, 900, 1800, 3600]
    let columnLayout = Array(repeating: GridItem(), count: 2)
    
    var body: some View {
        Group {
            ZStack(alignment: .center) {
                Image("VintageTimerBg")
                
                TickRingView(remaining: viewModel.remaining, theme: .init(ringBase: FloaterColor.gold, ringActive: FloaterColor.gold))
                
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
    VintageTimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5, type: .vintageDefault)))
        .frame(width: 220, height: 220)
}
