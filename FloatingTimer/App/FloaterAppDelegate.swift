//
//  FloaterAppDelegate.swift
//  Floater
//
//  Created by Christopher Susandji on 12/08/26.
//

import AppKit

class FloaterAppDelegate: NSResponder, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        CameraExtensionManager.shared.install()

        let hiddenIndexes = [1, 2, 4] // 1 = File, 2 = Edit, 4 = Help
        if let items = NSApp.mainMenu?.items {
            hiddenIndexes
                .compactMap { items.indices.contains($0) ? items[$0] : nil }
                .forEach { $0.isHidden = true }
        }
    }
}
