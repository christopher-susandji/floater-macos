//
//  TimerListCell.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 03/08/26.
//

import SwiftUI

struct TimerListCell: View {
    @Bindable var viewModel: TimerViewModel
    @Environment(AppViewModel.self) private var appViewModel
    var onDelete: (() -> Void)?
    @Namespace private var namespace
    @FocusState private var isTitleFocused: Bool

    private var isBroadcasting: Bool {
        appViewModel.broadcastTimerID == viewModel.id
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Sizing.xxs) {
                HStack(spacing: Sizing.xs) {
                    Button {
                        if isBroadcasting {
                            appViewModel.stopBroadcast()
                        } else {
                            appViewModel.startBroadcast(timerID: viewModel.id)
                        }
                    } label: {
                        Image(systemName: isBroadcasting ? "video.fill" : "video")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isBroadcasting ? viewModel.accentColor : viewModel.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help(isBroadcasting ? "Stop broadcasting to Keynote" : "Broadcast this timer as a live video source")

                    TextField("", text: $viewModel.title)
                    .overlay(alignment: .leading) {
                        if viewModel.title.isEmpty {
                            Text(Constants.untitled)
                                .foregroundStyle(viewModel.textSecondary)
                                .allowsHitTesting(false)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .default))
                    .fontWeight(.medium)
                    .fontWidth(.expanded)
                    .foregroundStyle(viewModel.title.count > 0 ? viewModel.textPrimary : viewModel.textSecondary.opacity(0.5))
                    .focused($isTitleFocused)
                    .onChange(of: viewModel.title) { oldValue, newValue in
                        if newValue.count > Constants.characterLimit {
                            viewModel.title = String(newValue.prefix(Constants.characterLimit))
                        } else {
                            viewModel.title = newValue.uppercased()
                        }
                    }
                }
                
                Text(viewModel.timeText)
                    .contentTransition(.numericText(countsDown: true))
                    .font(.system(.title, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isRunning ? viewModel.textPrimary : viewModel.textSecondary)
                    .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
                    .transition(.opacity)
            }
            
            Spacer()
            
            TimerControls(
                viewModel: viewModel,
                namespace: namespace,
                configuration: .init(style: .compact, accentColor: viewModel.accentColor),
                onPlayPause: { viewModel.startPause() },
                onReset: { viewModel.reset() },
                onEdit: {
                    FloatingTimerManager.shared.focusTimer(viewModel.id)
                    viewModel.requestEditMode()
                },
                onDelete: {
                    onDelete?()
                    FloatingTimerManager.shared.closeTimer(viewModel.id)
                }
            )
        }
        .padding(Sizing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            isTitleFocused = false
        }
    }
}
