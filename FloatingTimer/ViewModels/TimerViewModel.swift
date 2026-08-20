//
//  TimerViewModel.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import Foundation
import Observation
import AppKit
import AVFoundation
import SwiftUI

@MainActor
@Observable
final class TimerViewModel {
    enum State { case idle, running, paused, finished }
    
    var model: TimerModel
    
    var remaining: TimeInterval
    var isRunning: Bool = false
    
    var timerState: State = .idle
    
    /// Bumped whenever something external (e.g. the timer list) requests that this
    /// timer's floating panel open its preset-editing screen. `TimerView` observes
    /// this via `.onChange` and toggles its own local `editMode` state accordingly.
    var editRequestToken: Int = 0
    
    @ObservationIgnored
    private var ticker: Timer?
    
    @ObservationIgnored
    private var chimePlayer: AVAudioPlayer?
    
    @ObservationIgnored
    private var hasPlayedWarningChime = false
    
    let chimeOffset: Double = 0.0
    
    init(model: TimerModel) {
        self.model = model
        self.remaining = model.duration
    }
    
    deinit {
        ticker?.invalidate()
    }
    
    var id: UUID { model.id }
    var title: String {
        get { model.title }
        set { model.title = newValue }
    }
    var duration: TimeInterval { model.duration }
    
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
        
        return formatter.string(from: model.duration) ?? ""
    }
    
    func updateTimer(time: TimeInterval) {
        model = .init(id: model.id, title: model.title, duration: time)
        self.remaining = model.duration
    }
    
    /// Requests that this timer's floating panel open its preset-editing screen.
    func requestEditMode() {
        editRequestToken += 1
    }
    
    func startPause() {
        isRunning.toggle()
        withAnimation(.easeInOut) {
            self.timerState = isRunning ? .running : .paused
        }
        isRunning ? startTicker() : stopTicker()
    }
    
    func reset() {
        hasPlayedWarningChime = false
        stopTicker()
        isRunning = false
        withAnimation(.easeInOut) {
            timerState = .idle
        }
        remaining = duration
    }
    
    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.remaining > 0 else { return }
                
                self.remaining -= 1
                
                if self.remaining <= chimeOffset && !self.hasPlayedWarningChime {
                    self.hasPlayedWarningChime = true
                    self.playCompletionChime()
                }
                
                if self.remaining == 0 {
                    self.isRunning = false
                    withAnimation(.easeInOut) {
                        self.timerState = .finished
                    }
                    self.stopTicker()
                }
            }
        }
    }
    
    
    private func playCompletionChime() {
        guard let url = Bundle.main.url(forResource: "minimal-cinematic", withExtension: "mp3") else {
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
