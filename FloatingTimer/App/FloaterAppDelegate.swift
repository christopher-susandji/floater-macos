//
//  FloaterAppDelegate.swift
//  Floater
//
//  Created by Christopher Susandji on 12/08/26.
//

import AppKit

class FloaterAppDelegate: NSResponder, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        setupStatusItem()

        let hiddenIndexes = [1, 2, 4] // 1 = File, 2 = Edit, 4 = Help
        if let items = NSApp.mainMenu?.items {
            hiddenIndexes
                .compactMap { items.indices.contains($0) ? items[$0] : nil }
                .forEach { $0.isHidden = true }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Floater")
        }
        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Floater Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Floater", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
