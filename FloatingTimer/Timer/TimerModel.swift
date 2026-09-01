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

    init(id: UUID = UUID(), title: String, duration: TimeInterval, type: TimerType = .classicDefault) {
        self.id = id
        self.title = title
        self.duration = duration
        self.type = type
    }
}
