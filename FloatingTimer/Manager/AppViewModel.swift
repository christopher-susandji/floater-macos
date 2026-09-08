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
        }
    }

    private enum Keys {
        static let broadcastBackground = "broadcastBackgroundColor"
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
        timerViewModels.removeAll { $0.id == id }
    }

    func timerViewModel(id: UUID) -> TimerViewModel? {
        timerViewModels.first { $0.id == id }
    }

    // - MARK: Live video broadcast

    /// Starts (or restarts) broadcasting the given timer as a live-video source.
    func startBroadcast(timerID: UUID) {
        broadcastTimerID = timerID
        LiveVideoFrameSource.shared.viewModel = timerViewModel(id: timerID)
        LiveVideoFrameSource.shared.backgroundColor = broadcastBackgroundColor
        LiveVideoFrameSource.shared.start()
        isBroadcasting = true
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
