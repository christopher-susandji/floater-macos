//
//  FloaterAppShortcuts.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 01/09/26.
//

import AppIntents

struct FloaterAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: [
                "Start a \(.applicationName) timer",
                "Set a \(.applicationName) timer",
                "Start \(.applicationName)",
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: PauseTimerIntent(),
            phrases: [
                "Pause the \(.applicationName) timer",
                "Pause \(.applicationName)",
            ],
            shortTitle: "Pause Timer",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeTimerIntent(),
            phrases: [
                "Resume the \(.applicationName) timer",
                "Resume \(.applicationName)",
            ],
            shortTitle: "Resume Timer",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StopTimerIntent(),
            phrases: [
                "Stop the \(.applicationName) timer",
                "Stop \(.applicationName)",
            ],
            shortTitle: "Stop Timer",
            systemImageName: "stop.circle"
        )
    }
}
