//
//  StartTimerIntent.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 01/09/26.
//

import AppIntents
import Foundation

/// "Start a timer for 5 minutes" — creates a timer and shows its floating panel.
struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription(
        "Creates a new timer with the given duration and starts it immediately.",
        categoryName: "Timer",
        searchKeywords: ["countdown", "minute", "hour"]
    )

    /// Brings the app forward so the new floating timer panel is visible.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Duration", description: "How long the timer should run.")
    var duration: Measurement<UnitDuration>

    @Parameter(title: "Title", description: "An optional name shown on the timer.")
    var title: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Start a timer for \(\.$duration)") {
            \.$title
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let seconds: Double = duration.converted(to: .seconds).value
        guard seconds > 0 else { throw TimerIntentError.invalidDuration }
        guard AppViewModel.shared.canCreateTimer else { throw TimerIntentError.maximumTimersReached }
        guard let viewModel = AppViewModel.shared.createTimer(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            seconds: Int(seconds)
        ) else { throw TimerIntentError.creationFailed }
        
        viewModel.startPause()

        FloatingTimerManager.shared.showTimer(viewModel, in: AppViewModel.shared)

        return .result(dialog: "\(viewModel.displayName) started for \(viewModel.initialTimeText).")
    }
}
