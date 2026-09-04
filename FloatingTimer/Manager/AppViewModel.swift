//
//  AppViewModel.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppViewModel {
    nonisolated static let maxTimerCount = 5

    /// The single instance shared by the UI and App Intents, so a timer started
    /// via Siri/Spotlight appears in the same window as one started by hand.
    static let shared = AppViewModel()

    var timerViewModels: [TimerViewModel] = []
    
    var canCreateTimer: Bool {
        timerViewModels.count < Self.maxTimerCount
    }
    
    @discardableResult
    func createTimer(title: String, seconds: Int, type: TimerType = .classicDefault) -> TimerViewModel? {
        guard canCreateTimer else { return nil }
        let model = TimerModel(title: title, duration: TimeInterval(seconds), type: type)
        let viewModel = TimerViewModel(model: model)
        timerViewModels.append(viewModel)
        return viewModel
    }

    func removeTimer(id: UUID) {
        timerViewModels.removeAll { $0.id == id }
    }

    func timerViewModel(id: UUID) -> TimerViewModel? {
        timerViewModels.first { $0.id == id }
    }
}
