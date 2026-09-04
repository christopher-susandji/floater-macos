//
//  TimerModel.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//
import Foundation

struct TimerModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var type: TimerType
    /// Full file name (with extension) of the completion chime, e.g.
    /// "minimal-cinematic.mp3". May be a bundled resource or, in future, a
    /// user-uploaded file.
    var chime: String

    init(id: UUID = UUID(), title: String, duration: TimeInterval, type: TimerType = .classicDefault, chime: String? = nil) {
        self.id = id
        self.title = title
        self.duration = duration
        self.type = type
        self.chime = chime ?? type.defaultChimeFileName
    }
}
