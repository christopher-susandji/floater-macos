//
//  FloatingTimerApp.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

@main
struct FloaterApp: App {
    @State private var appViewModel = AppViewModel.shared
    @NSApplicationDelegateAdaptor private var appDelegate: FloaterAppDelegate
    @Environment(\.openSettings) private var openSettings
    
    var body: some Scene {
        WindowGroup("Floater") {
            ContentView()
                .environment(appViewModel)
                .preferredColorScheme(.dark)
                .frame(width: 300)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    appDelegate.openSettingsAction = openSettings
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) { }
            CommandGroup(replacing: .help) { }
            CommandGroup(replacing: .textEditing) { }
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .sidebar) { }
            CommandGroup(replacing: .systemServices) { }
        }

        Settings {
            SettingsView()
        }
    }
}
