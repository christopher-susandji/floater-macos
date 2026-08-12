//
//  FloaterAppDelegate.swift
//  Floater
//
//  Created by Christopher Susandji on 12/08/26.
//

import AppKit

class FloaterAppDelegate: NSResponder, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide menu items we don't want the user to have access to
        [1, 2, 4] // 1 = File, 2 = Edit, 4 = Help
            .compactMap { NSApp.mainMenu?.item(at: $0) }
            .forEach { $0.isHidden = true }
    }
}
