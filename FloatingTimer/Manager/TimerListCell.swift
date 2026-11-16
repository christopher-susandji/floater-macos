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
    @State private var cameraExtensionManager = CameraExtensionManager.shared
    var onDelete: (() -> Void)?
    @Namespace private var namespace
    @FocusState private var isTitleFocused: Bool

    @State private var isEditingTime = false
    @State private var draftHours = 0
    @State private var draftMinutes = 0
    @State private var draftSeconds = 0
    @FocusState private var focusedTimeField: TimeField?

    private enum TimeField: Hashable {
        case hours, minutes, seconds
    }

    private var isBroadcasting: Bool {
        appViewModel.broadcastTimerID == viewModel.id
    }

    /// A running timer can't be edited, matching the floating panel, where the
    /// edit screen is only reachable once the countdown is stopped or paused.
    private var canEditTime: Bool {
        viewModel.timerState != .running
    }

    /// Whether the open editor shows an hours field. Frozen when editing starts,
    /// so clearing the hours doesn't pull the field out from under the cursor.
    private var editorShowsHours: Bool {
        isEditingTime ? usesHoursField : viewModel.duration >= 3600
    }

    @State private var usesHoursField = false

    private var editorFontSize: CGFloat {
        editorShowsHours ? 20 : 26
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sizing.xs) {
            titleRow

            HStack(alignment: .center) {
                timeView

                Spacer()

                TimerControls(
                    viewModel: viewModel,
                    namespace: namespace,
                    configuration: .init(style: .compact, accentColor: viewModel.accentColor),
                    onPlayPause: {
                        commitTimeEdit()
                        viewModel.startPause()
                    },
                    onReset: {
                        commitTimeEdit()
                        viewModel.reset()
                    },
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
        }
        .padding(Sizing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            isTitleFocused = false
            focusedTimeField = nil
        }
        .onChange(of: focusedTimeField) { _, newValue in
            // Tabbing or clicking away commits, the way a text field would.
            if newValue == nil {
                commitTimeEdit()
            }
        }
    }

    // - MARK: Title

    private var titleRow: some View {
        HStack(spacing: Sizing.xs) {
            if cameraExtensionManager.isInstalled && appViewModel.isCameraInputEnabled {
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
            }

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
    }

    // - MARK: Time

    @ViewBuilder
    private var timeView: some View {
        if isEditingTime {
            timeEditor
        } else {
            Text(viewModel.timeText)
                .contentTransition(.numericText(countsDown: true))
                .font(.system(.title, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(viewModel.isRunning ? viewModel.textPrimary : viewModel.textSecondary)
                .animation(viewModel.isRunning ? .linear(duration: 0.2) : nil, value: viewModel.timeText)
                .transition(.opacity)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard canEditTime else { return }
                    beginTimeEdit()
                }
                .help(canEditTime ? "Click to change the duration" : "Stop the timer to change its duration")
        }
    }

    private var timeEditor: some View {
        HStack(spacing: Sizing.xxs) {
            if editorShowsHours {
                TimeTextField(
                    value: $draftHours,
                    max: 23,
                    fontSize: editorFontSize,
                    onMoveRight: { focusedTimeField = .minutes },
                    onEnter: { commitTimeEdit() },
                    onEscape: { cancelTimeEdit() }
                )
                .focused($focusedTimeField, equals: .hours)

                timeSeparator
            }

            TimeTextField(
                value: $draftMinutes,
                max: 59,
                fontSize: editorFontSize,
                onMoveLeft: editorShowsHours ? { focusedTimeField = .hours } : nil,
                onMoveRight: { focusedTimeField = .seconds },
                onEnter: { commitTimeEdit() },
                onEscape: { cancelTimeEdit() }
            )
            .focused($focusedTimeField, equals: .minutes)

            timeSeparator

            TimeTextField(
                value: $draftSeconds,
                max: 59,
                fontSize: editorFontSize,
                onMoveLeft: { focusedTimeField = .minutes },
                onEnter: { commitTimeEdit() },
                onEscape: { cancelTimeEdit() }
            )
            .focused($focusedTimeField, equals: .seconds)
        }
    }

    private var timeSeparator: some View {
        Text(":")
            .font(.system(size: editorFontSize * 0.7, weight: .semibold, design: .monospaced))
            .foregroundStyle(viewModel.textSecondary)
    }

    // - MARK: Time editing

    private func beginTimeEdit() {
        let total = Int(viewModel.duration)
        draftHours = total / 3600
        draftMinutes = (total % 3600) / 60
        draftSeconds = total % 60
        usesHoursField = total >= 3600

        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingTime = true
        }

        DispatchQueue.main.async {
            focusedTimeField = usesHoursField ? .hours : .minutes
        }
    }

    private func commitTimeEdit() {
        guard isEditingTime else { return }

        let total = draftHours * 3600 + draftMinutes * 60 + draftSeconds

        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingTime = false
        }
        focusedTimeField = nil

        // A zero-length timer would leave the cell with nothing to run.
        guard total > 0 else {
            NSSound.beep()
            return
        }

        viewModel.updateTimer(time: TimeInterval(total))
    }

    private func cancelTimeEdit() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingTime = false
        }
        focusedTimeField = nil
    }
}

#Preview {
    TimerListCell(
        viewModel: TimerViewModel(model: TimerModel(title: "HELLO WORRRRLLLDDDD", duration: 1000)),
        onDelete: { }
    )
    .environment(AppViewModel())
    .padding()
    .frame(width: 300)
}

#Preview("Long timer") {
    TimerListCell(
        viewModel: TimerViewModel(model: TimerModel(title: "Deep Work", duration: 5400)),
        onDelete: { }
    )
    .environment(AppViewModel())
    .padding()
    .frame(width: 300)
}
