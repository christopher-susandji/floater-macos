//
//  TimerModel.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//
import Foundation

struct TimerModel: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var duration: TimeInterval

    init(id: UUID = UUID(), title: String, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}
