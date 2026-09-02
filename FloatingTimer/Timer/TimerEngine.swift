//
//  TimerEngine.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/08/26.
//

import Foundation
import Observation
import AppKit
import AVFoundation

/// Pure timer logic: state machine, ticking, completion chime and time
/// formatting. UI-free — views and `TimerViewModel` own animations and
/// presentation concerns.
@MainActor
@Observable
final class TimerEngine {
    enum State {
        case idle, running, paused, finished
    }

    var remaining: TimeInterval
    var isRunning: Bool = false
    var timerState: State = .idle

    private(set) var duration: TimeInterval

    private(set) var chimeResourceName: String

    let chimeOffset: Double = 0.0

    @ObservationIgnored
    private var ticker: Timer?

    @ObservationIgnored
    private var chimePlayer: AVAudioPlayer?

    @ObservationIgnored
    private var hasPlayedWarningChime = false

    init(duration: TimeInterval, chimeResourceName: String) {
        self.duration = duration
        self.chimeResourceName = chimeResourceName
        self.remaining = duration
    }

    deinit {
        ticker?.invalidate()
    }

    var timeText: String {
        let total = max(0, Int(remaining))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var durationTimeText: String {
        let total = max(0, Int(duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var initialTimeText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated

        return formatter.string(from: duration) ?? ""
    }

    func startPause() {
        isRunning.toggle()
        timerState = isRunning ? .running : .paused
        isRunning ? startTicker() : stopTicker()
    }

    func reset() {
        hasPlayedWarningChime = false
        stopTicker()
        isRunning = false
        timerState = .idle
        remaining = duration
    }

    func setChime(_ resourceName: String) {
        chimeResourceName = resourceName
    }

    /// Applies a new duration (from editing) and restarts from idle.
    func update(duration: TimeInterval) {
        self.duration = duration
        reset()
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.remaining > 0 else { return }

                self.remaining -= 1

                if self.remaining <= self.chimeOffset && !self.hasPlayedWarningChime {
                    self.hasPlayedWarningChime = true
                    self.playCompletionChime()
                }

                if self.remaining == 0 {
                    self.isRunning = false
                    self.timerState = .finished
                    self.stopTicker()
                }
            }
        }
    }

    private func playCompletionChime() {
        guard let url = Bundle.main.url(forResource: chimeResourceName, withExtension: "mp3") else {
            return
        }
        do {
            chimePlayer = try AVAudioPlayer(contentsOf: url)
            chimePlayer?.play()
        } catch {
            if let sound = NSSound(named: NSSound.Name("Hero")) {
                sound.play()
            }
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}