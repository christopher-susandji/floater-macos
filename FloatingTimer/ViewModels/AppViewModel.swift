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
    static let maxTimerCount = 5
    
    var timerViewModels: [TimerViewModel] = []
    
    var canCreateTimer: Bool {
        timerViewModels.count < Self.maxTimerCount
    }
    
    @discardableResult
    func createTimer(title: String, seconds: Int) -> TimerViewModel? {
        guard canCreateTimer else { return nil }
        let model = TimerModel(title: title, duration: TimeInterval(seconds))
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
