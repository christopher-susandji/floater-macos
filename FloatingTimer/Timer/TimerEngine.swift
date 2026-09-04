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

    private(set) var chimeFileName: String

    let chimeOffset: Double = 0.0

    @ObservationIgnored
    private var ticker: Timer?

    @ObservationIgnored
    private var chimePlayer: AVAudioPlayer?

    @ObservationIgnored
    private var hasPlayedWarningChime = false

    init(duration: TimeInterval, chimeFileName: String) {
        self.duration = duration
        self.chimeFileName = chimeFileName
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

    func setChime(_ fileName: String) {
        chimeFileName = fileName
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
        guard let url = url(forChime: chimeFileName) else {
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

    /// Resolves a chime identifier to a playable audio URL. Identifiers may be:
    /// - a full file path (user-uploaded audio),
    /// - a bundled resource file name such as "minimal-cinematic.mp3".
    private func url(forChime chime: String) -> URL? {
        if chime.hasPrefix("/") {
            return URL(fileURLWithPath: chime)
        }

        let name = (chime as NSString).deletingPathExtension
        let ext = (chime as NSString).pathExtension
        let resource = Bundle.main.url(forResource: name, withExtension: ext)
        if resource != nil { return resource }

        // Fall back to any bundled resource matching the base name.
        let anyExtension = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil)?
            .first { $0.deletingPathExtension().lastPathComponent == name }
        return anyExtension
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}