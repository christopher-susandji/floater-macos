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

    init() {
        self.isSingleTimerMode = UserDefaults.standard.object(forKey: Keys.singleTimerMode) as? Bool ?? false
    }

    /// The timer currently selected for live-video broadcast. `nil` means
    /// `LiveVideoFrameSource` renders its placeholder.
    var broadcastTimerID: UUID?

    /// Whether the live-video source is actively pushing frames into the camera.
    /// The camera can only ever carry one timer, so this and `broadcastTimerID`
    /// are the whole camera state — there is no separate "show the button"
    /// preference.
    var isBroadcasting: Bool = false

    /// Whether the desktop shows one floating timer at a time instead of one per
    /// timer. Persisted, because it describes how the app behaves rather than
    /// which timers exist. Defaults to off.
    var isSingleTimerMode: Bool {
        didSet {
            UserDefaults.standard.set(isSingleTimerMode, forKey: Keys.singleTimerMode)
        }
    }

    /// The timer currently floating on the desktop in single mode. Session-only,
    /// since the timers themselves don't survive a relaunch either.
    var activeTimerID: UUID?

    /// Turns single-panel mode on or off, collapsing or leaving the desktop
    /// timers to match.
    func setSingleTimerMode(_ enabled: Bool) {
        guard enabled != isSingleTimerMode else { return }
        isSingleTimerMode = enabled
        FloatingTimerManager.shared.applySingleTimerMode(in: self)
    }

    /// The solid backdrop color painted behind the timer in the live-video
    /// feed (persisted across launches). Defaults to black.
    var broadcastBackgroundColor: Color {
        get {
            let defaults = UserDefaults.standard
            if let components = defaults.object(forKey: Keys.broadcastBackground) as? [Double], components.count == 3 {
                return Color(red: components[0], green: components[1], blue: components[2])
            }
            return .black
        }
        set {
            if let components = newValue.rgbComponents {
                UserDefaults.standard.set(components, forKey: Keys.broadcastBackground)
            }
            if isBroadcasting {
                LiveVideoFrameSource.shared.backgroundColor = newValue
            }
        }
    }

    private enum Keys {
        static let broadcastBackground = "broadcastBackgroundColor"
        static let singleTimerMode = "singleTimerMode"
    }

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
        if activeTimerID == id {
            activeTimerID = nil
        }
        timerViewModels.removeAll { $0.id == id }
    }

    func timerViewModel(id: UUID) -> TimerViewModel? {
        timerViewModels.first { $0.id == id }
    }

    // - MARK: Live video broadcast

    /// Starts (or restarts) broadcasting the given timer as a live-video source.
    /// The camera can only carry one timer, so broadcasting also puts the app in
    /// single-panel mode with that timer chosen.
    func startBroadcast(timerID: UUID) {
        activeTimerID = timerID
        broadcastTimerID = timerID
        LiveVideoFrameSource.shared.viewModel = timerViewModel(id: timerID)
        LiveVideoFrameSource.shared.backgroundColor = broadcastBackgroundColor
        LiveVideoFrameSource.shared.start()
        isBroadcasting = true

        if !isSingleTimerMode {
            setSingleTimerMode(true)
        }
    }

    /// Points an already-running feed at another timer, without restarting the
    /// camera stream. Single-panel mode uses this when the user selects a
    /// different timer while broadcasting.
    func retargetBroadcast(timerID: UUID) {
        guard isBroadcasting, let timer = timerViewModel(id: timerID) else { return }
        broadcastTimerID = timerID
        LiveVideoFrameSource.shared.viewModel = timer
    }

    /// Stops broadcasting and returns the camera to its placeholder output.
    func stopBroadcast() {
        LiveVideoFrameSource.shared.showPlaceholder()
        broadcastTimerID = nil
        isBroadcasting = false
    }
}

private extension Color {
    /// Linear RGB components `[red, green, blue]` in 0...1, or `nil` if the
    /// color can't be resolved to device RGB.
    var rgbComponents: [Double]? {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        return [Double(rgb.redComponent), Double(rgb.greenComponent), Double(rgb.blueComponent)]
    }
}
