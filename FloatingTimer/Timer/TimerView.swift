//
//  TimerView.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

/// Dispatches to the view variant for the timer's `TimerType`.
/// The type carries its own theme, so theming is enforced per type.
struct TimerView: View {
    var viewModel: TimerViewModel
    var onDelete: (() -> Void)?

    init(viewModel: TimerViewModel, onDelete: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onDelete = onDelete
    }

    var body: some View {
        switch viewModel.type {
        case .classic:
            ClassicTimerView(viewModel: viewModel, onDelete: onDelete)
        case .vintage:
            VintageTimerView(viewModel: viewModel, onDelete: onDelete)
        }
    }
}

#Preview {
    TimerView(viewModel: TimerViewModel(model: TimerModel(title: "Focus", duration: 5)))
        .frame(width: 220, height: 220)
}