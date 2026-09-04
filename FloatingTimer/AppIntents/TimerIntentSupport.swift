//
//  TimerIntentSupport.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 01/09/26.
//

import Foundation

/// Errors surfaced to Siri/Spotlight when a timer intent can't run.
enum TimerIntentError: LocalizedError {
    case invalidDuration
    case maximumTimersReached
    case creationFailed
    case noTimers
    case timerNotRunning
    case timerNotPaused

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "Please provide a duration greater than zero seconds."
        case .maximumTimersReached:
            return "You already have \(AppViewModel.maxTimerCount) timers. Remove one before starting another."
        case .creationFailed:
            return "The timer couldn't be created."
        case .noTimers:
            return "There is no timer to control. Start one first."
        case .timerNotRunning:
            return "The timer isn't running right now."
        case .timerNotPaused:
            return "The timer isn't paused right now."
        }
    }
}

/// The most recently created timer, which is the default target for
/// pause / resume / stop commands.
@MainActor
func latestTimer() throws -> TimerViewModel {
    guard let viewModel = AppViewModel.shared.timerViewModels.last else {
        throw TimerIntentError.noTimers
    }
    return viewModel
}

extension TimerViewModel {
    /// A user-facing name that falls back to "Timer" when no title is set.
    var displayName: String {
        title.isEmpty ? "Timer" : title
    }
}

extension Duration {
    /// The total length of the duration in whole seconds.
    var totalSeconds: Int {
        Int(components.seconds) + Int(components.attoseconds) / 1_000_000_000_000_000_000
    }
}