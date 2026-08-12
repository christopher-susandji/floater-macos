//
//  FloatingTimerApp.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

@main
struct FloaterApp: App {
    @State private var appViewModel = AppViewModel()
    @NSApplicationDelegateAdaptor private var appDelegate: FloaterAppDelegate
    
    var body: some Scene {
        WindowGroup("Floater") {
            ContentView()
                .environment(appViewModel)
                .frame(width: 300)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
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
    }
}
