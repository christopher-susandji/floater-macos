//
//  TimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

/// Dispatches to the view variant for the timer's `TimerType` and owns the
/// shared edit-mode overlay (type picker, theme swatches, preset grid) so it
/// isn't duplicated inside each timer type.
struct TimerView: View {
    var viewModel: TimerViewModel
    var onDelete: (() -> Void)?

    @State private var editMode = false

    private let minutes: [TimeInterval] = [60, 120, 180, 300, 600, 900, 1800, 3600]

    init(viewModel: TimerViewModel, onDelete: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .center) {
            switch viewModel.type {
            case .classic:
                ClassicTimerView(viewModel: viewModel, onDelete: onDelete, onEdit: { toggleEdit() })
            case .vintage:
                VintageTimerView(viewModel: viewModel, onDelete: onDelete, onEdit: { toggleEdit() })
            }

            if editMode {
                editOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .onChange(of: viewModel.editRequestToken) { _, newValue in
            withAnimation(.easeInOut(duration: 0.15)) {
                editMode = newValue > 0
            }
        }
    }

    private var editOverlay: some View {
        TimerEditView(
            headerColor: viewModel.textSecondary,
            typeOptions: viewModel.typeOptions,
            themeOptions: viewModel.themeOptions,
            chimeOptions: viewModel.chimeOptions,
            minutes: minutes,
            presetAction: { time in
                toggleEdit()
                viewModel.updateTimer(time: time)
            },
            closeAction: { toggleEdit() }
        )
    }

    private func toggleEdit() {
        withAnimation(.easeInOut(duration: 0.15)) {
            editMode.toggle()
        }
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}