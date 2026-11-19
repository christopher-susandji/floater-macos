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

    @State private var isHovered = false

    @State private var isEditingTime = false
    @State private var draftHours = 0
    @State private var draftMinutes = 0
    @State private var draftSeconds = 0
    @FocusState private var focusedTimeField: TimeField?

    private enum TimeField: Hashable {
        case hours, minutes, seconds
    }

    private var isOnDesktop: Bool {
        appViewModel.activeTimerID == viewModel.id
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

    private var timeFont: Font {
        .system(.title, design: .monospaced)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Sizing.xs) {
            titleRow

            HStack(alignment: .center) {
                timeView

                Spacer()

                TimerListControls(
                    viewModel: viewModel,
                    namespace: namespace,
                    accentColor: viewModel.accentColor,
                    isEditingDuration: isEditingTime,
                    onPlayPause: {
                        commitTimeEdit()
                        viewModel.startPause()
                    },
                    onStop: {
                        commitTimeEdit()
                        viewModel.reset()
                    },
                    onToggleEdit: {
                        if isEditingTime {
                            cancelTimeEdit()
                        } else {
                            // Opens the duration fields on the last one, which is
                            // where a new duration usually gets typed.
                            beginTimeEdit(focusing: .seconds)
                        }
                    },
                    onDelete: {
                        onDelete?()
                        FloatingTimerManager.shared.closeTimer(viewModel.id, in: appViewModel)
                    }
                )
            }
        }
        .padding(Sizing.xs)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.12), value: appViewModel.isSingleTimerMode)
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
        HStack(spacing: 0) {
            // Kept in the layout at all times so showing or hiding it can't
            // change the row's height; only its width and opacity animate.
            pinButton
                .frame(width: showsPinButton ? 14 : 0, height: 14)
                .padding(.trailing, showsPinButton ? Sizing.xs : 0)
                .opacity(showsPinButton ? 1 : 0)
                .allowsHitTesting(showsPinButton)
                .clipped()

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

    /// The one control at the top of the row: it picks the timer, which is what
    /// the desktop shows in single mode and what the camera shows either way.
    /// It stays visible once pinned and otherwise only appears while the row is
    /// hovered, so an idle list stays quiet.
    private var pinButton: some View {
        Button {
            if isOnDesktop {
                FloatingTimerManager.shared.deactivate(in: appViewModel)
            } else {
                FloatingTimerManager.shared.activate(viewModel, in: appViewModel)
            }
        } label: {
            Image(systemName: isOnDesktop ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isOnDesktop ? viewModel.accentColor : viewModel.textSecondary.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help(isOnDesktop ? "This timer is the chosen one" : "Choose this timer")
        .accessibilityLabel(isOnDesktop ? "Chosen timer" : "Choose this timer")
    }

    /// With one timer at a time the pin is how you swap which timer floats, so it
    /// is only offered in that mode: always visible once pinned, otherwise on
    /// hover.
    private var showsPinButton: Bool {
        appViewModel.isSingleTimerMode && (isOnDesktop || isHovered)
    }

    // - MARK: Time

    @ViewBuilder
    private var timeView: some View {
        if isEditingTime {
            timeEditor
        } else {
            Text(viewModel.timeText)
                .contentTransition(.numericText(countsDown: true))
                .font(timeFont)
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
        HStack(spacing: .zero) {
            if editorShowsHours {
                TimeTextField(
                    value: $draftHours,
                    max: 23,
                    font: timeFont,
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
                font: timeFont,
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
                font: timeFont,
                onMoveLeft: { focusedTimeField = .minutes },
                onEnter: { commitTimeEdit() },
                onEscape: { cancelTimeEdit() }
            )
            .focused($focusedTimeField, equals: .seconds)
        }
        .foregroundStyle(viewModel.textSecondary)
    }

    private var timeSeparator: some View {
        Text(":")
            .font(timeFont)
            .foregroundStyle(viewModel.textSecondary)
    }

    // - MARK: Time editing

    private func beginTimeEdit(focusing field: TimeField? = nil) {
        let total = Int(viewModel.duration)
        draftHours = total / 3600
        draftMinutes = (total % 3600) / 60
        draftSeconds = total % 60
        usesHoursField = total >= 3600

        withAnimation(.easeInOut(duration: 0.15)) {
            isEditingTime = true
        }

        DispatchQueue.main.async {
            focusedTimeField = field ?? (usesHoursField ? .hours : .minutes)
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
