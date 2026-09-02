//
//  TimerControlIntents.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 01/09/26.
//

import AppIntents
import Foundation

/// "Pause the timer" — pauses the most recently created timer.
struct PauseTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Timer"
    static let description = IntentDescription(
        "Pauses the most recently created timer.",
        categoryName: "Timer"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let viewModel = try latestTimer()
        guard viewModel.isRunning else { throw TimerIntentError.timerNotRunning }
        viewModel.startPause()
        return .result(dialog: "\(viewModel.displayName) paused.")
    }
}

/// "Resume the timer" — resumes a paused timer.
struct ResumeTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Timer"
    static let description = IntentDescription(
        "Resumes the most recently created timer.",
        categoryName: "Timer"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let viewModel = try latestTimer()
        guard viewModel.timerState == .paused else { throw TimerIntentError.timerNotPaused }
        viewModel.startPause()
        return .result(dialog: "\(viewModel.displayName) resumed.")
    }
}

/// "Stop the timer" — resets the most recently created timer back to its duration.
struct StopTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Timer"
    static let description = IntentDescription(
        "Stops and resets the most recently created timer.",
        categoryName: "Timer"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let viewModel = try latestTimer()
        viewModel.reset()
        return .result(dialog: "\(viewModel.displayName) stopped.")
    }
}