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

    /// The timer currently selected for live-video broadcast. `nil` means
    /// `LiveVideoFrameSource` renders its placeholder.
    var broadcastTimerID: UUID?

    /// Whether the live-video source is actively pushing frames into the camera.
    var isBroadcasting: Bool = false

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
        if broadcastTimerID == id {
            stopBroadcast()
        }
        timerViewModels.removeAll { $0.id == id }
    }

    func timerViewModel(id: UUID) -> TimerViewModel? {
        timerViewModels.first { $0.id == id }
    }

    // - MARK: Live video broadcast

    /// Starts (or restarts) broadcasting the given timer as a live-video source.
    func startBroadcast(timerID: UUID) {
        guard let windowID = FloatingTimerManager.shared.windowID(for: timerID) else { return }
        broadcastTimerID = timerID
        LiveVideoFrameSource.shared.start(windowID: windowID)
        isBroadcasting = true
    }

    /// Stops broadcasting and returns the camera to its placeholder output.
    func stopBroadcast() {
        LiveVideoFrameSource.shared.stop()
        broadcastTimerID = nil
        isBroadcasting = false
    }
}
