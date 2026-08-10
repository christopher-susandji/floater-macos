//
//  FloatingTimerApp.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import SwiftUI

@main
struct FloatingTimerApp: App {
    @State private var appViewModel = AppViewModel()
    
    var body: some Scene {
        WindowGroup("Timer Manager") {
            ContentView()
                .environment(appViewModel)
                .frame(width: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
