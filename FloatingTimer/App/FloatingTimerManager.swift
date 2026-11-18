//
//  FloatingTimerManager.swift
//  FloatingTimer
//
//  Created by Christopher Susandji on 27/07/26.
//

import AppKit
import SwiftUI

class FloatingTimerManager: NSObject {
    static let shared = FloatingTimerManager()
    
    private var panels: [UUID: NSPanel] = [:]
    private var panelDelegates: [UUID: PanelDelegate] = [:]
    private var slots: [UUID: Int] = [:]
    
    /// Origin of the most recently active timer panel (the last one created,
    /// focused or dragged). New timers spawn here so they reuse the spot the
    /// user last placed a timer in. Kept in memory for the session only, and
    /// survives the active panel being closed so the next timer still lands
    /// where the previous one was.
    private var lastActiveOrigin: NSPoint?
    
    private let panelSize = NSSize(width: 220, height: 220)
    private let gridSpacing: CGFloat = 16
    private let columns = 3
    
    /// Finds the main "Floater" content window (as opposed to the floating timer panels we manage).
    private var mainWindow: NSWindow? {
        NSApp.windows.first { window in
            !(window is NSPanel) && window.isVisible
        }
    }
    
    private var targetScreen: NSScreen {
        mainWindow?.screen ?? NSScreen.main ?? NSScreen.screens[0]
    }
    
    private func nextAvailableSlot() -> Int {
        let used = Set(slots.values)
        var candidate = 0
        while used.contains(candidate) {
            candidate += 1
        }
        return candidate
    }
    
    private func frameOrigin(forSlot slot: Int) -> NSPoint {
        let screenFrame = targetScreen.visibleFrame
        
        // Top-right anchor point of the desktop.
        let anchorTopRight = NSPoint(x: screenFrame.maxX - gridSpacing, y: screenFrame.maxY - gridSpacing)
        
        let col = slot % columns
        let row = slot / columns
        
        let cellTopRightX = anchorTopRight.x - CGFloat(col) * (panelSize.width + gridSpacing)
        let x = cellTopRightX - panelSize.width
        
        let cellTopY = anchorTopRight.y - CGFloat(row) * (panelSize.height + gridSpacing)
        let originY = cellTopY - panelSize.height
        
        return NSPoint(x: x, y: originY)
    }

    /// Keeps a remembered origin on-screen, e.g. after a display change, so a
    /// new timer can't spawn somewhere the user can't reach it. The point is
    /// clamped to the display it was placed on, not the main window's screen,
    /// so a timer dragged to a secondary display stays there.
    private func sanitizedOrigin(_ origin: NSPoint) -> NSPoint {
        let screen = NSScreen.screens.first { $0.frame.contains(origin) } ?? targetScreen
        let screenFrame = screen.visibleFrame
        let maxX = screenFrame.maxX - panelSize.width
        let maxY = screenFrame.maxY - panelSize.height
        return NSPoint(
            x: min(max(origin.x, screenFrame.minX), maxX),
            y: min(max(origin.y, screenFrame.minY), maxY)
        )
    }
    
    /// The spot a new panel takes: wherever the last active timer was, or the
    /// grid when nothing has been placed yet this session.
    private func nextOrigin() -> NSPoint {
        lastActiveOrigin.map(sanitizedOrigin) ?? frameOrigin(forSlot: nextAvailableSlot())
    }
    
    /// Where the single desktop panel should sit when its timer is swapped: the
    /// outgoing panel's spot, so a swap doesn't move the timer across the screen.
    private func singlePanelOrigin(in appViewModel: AppViewModel) -> NSPoint {
        if let activeID = appViewModel.activeTimerID, let panel = panels[activeID] {
            return sanitizedOrigin(panel.frame.origin)
        }
        return nextOrigin()
    }
    
    // - MARK: Showing timers
    
    /// Puts a timer on the desktop. In single mode the desktop carries the first
    /// timer in the list, so that is what gets shown.
    func showTimer(_ viewModel: TimerViewModel, in appViewModel: AppViewModel) {
        if appViewModel.isSingleTimerMode {
            if let top = appViewModel.timerViewModels.first {
                activate(top, in: appViewModel)
            }
        } else {
            presentPanel(
                for: viewModel,
                in: appViewModel,
                at: nextOrigin(),
                slot: nextAvailableSlot()
            )
        }
    }
    
    /// Makes the given timer the one on the desktop, swapping out whichever timer
    /// was there.
    func activate(_ viewModel: TimerViewModel, in appViewModel: AppViewModel) {
        guard appViewModel.isSingleTimerMode else {
            showTimer(viewModel, in: appViewModel)
            return
        }
        
        // Already on the desktop: just bring it forward.
        if appViewModel.activeTimerID == viewModel.id, let panel = panels[viewModel.id] {
            lastActiveOrigin = panel.frame.origin
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        let origin = singlePanelOrigin(in: appViewModel)
        for id in Array(panels.keys) {
            tearDown(id)
        }
        
        appViewModel.activeTimerID = viewModel.id
        appViewModel.retargetBroadcast(timerID: viewModel.id)
        presentPanel(for: viewModel, in: appViewModel, at: origin, slot: nextAvailableSlot())
    }
    
    /// Clears the chosen timer, leaving it in the list. In single mode that also
    /// takes the timer off the desktop.
    func deactivate(in appViewModel: AppViewModel) {
        if appViewModel.isSingleTimerMode {
            for id in Array(panels.keys) {
                tearDown(id)
            }
        }
        appViewModel.activeTimerID = nil
        // Nothing is chosen, so the feed has nothing to show.
        appViewModel.stopBroadcast()
    }
    
    /// Collapses the desktop to one timer when single mode is turned on, keeping
    /// the one the user is looking at. Turning the mode off puts every timer back
    /// on the desktop, which is what "one timer at a time" being off means.
    func applySingleTimerMode(in appViewModel: AppViewModel) {
        guard appViewModel.isSingleTimerMode else {
            // The chosen timer survives the switch; it just stops limiting the
            // desktop, so put the rest back alongside it.
            presentTimersWithoutPanels(in: appViewModel)
            return
        }
        
        // With one timer at a time the desktop carries the first timer in the
        // list, so that is the one to keep.
        guard let keep = appViewModel.timerViewModels.first else {
            appViewModel.activeTimerID = nil
            return
        }
        
        for id in Array(panels.keys) where id != keep.id {
            tearDown(id)
        }
        
        appViewModel.activeTimerID = keep.id
        appViewModel.retargetBroadcast(timerID: keep.id)
        
        if panels[keep.id] == nil {
            presentPanel(for: keep, in: appViewModel, at: nextOrigin(), slot: nextAvailableSlot())
        }
    }
    
    /// Puts every timer that isn't on the desktop back on it, laid out on the grid
    /// so a restored set doesn't land on top of itself. The timer that was pinned
    /// keeps the spot the user left it in.
    private func presentTimersWithoutPanels(in appViewModel: AppViewModel) {
        var slot = nextAvailableSlot()
        for timer in appViewModel.timerViewModels where panels[timer.id] == nil {
            presentPanel(for: timer, in: appViewModel, at: frameOrigin(forSlot: slot), slot: slot)
            slot = nextAvailableSlot()
        }
    }
    
    
    // - MARK: Panels
    
    private func presentPanel(for viewModel: TimerViewModel, in appViewModel: AppViewModel, at origin: NSPoint, slot: Int) {
        if let panel = panels[viewModel.id] {
            panel.setFrameOrigin(origin)
            lastActiveOrigin = origin
            panel.makeKeyAndOrderFront(nil)
            return
        }
        
        let timerView = TimerView(viewModel: viewModel) { [weak self] in
            appViewModel.removeTimer(id: viewModel.id)
            self?.closeTimer(viewModel.id, in: appViewModel)
        }
            .environment(\.controlActiveState, .key)
        let hostingController = NSHostingController(rootView: timerView)
        
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.contentViewController = hostingController
        
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.title = viewModel.title
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        
        slots[viewModel.id] = slot
        panel.setFrameOrigin(origin)
        lastActiveOrigin = origin
        
        let panelDelegate = PanelDelegate(
            onClose: { [weak self] in
                self?.panels.removeValue(forKey: viewModel.id)
                self?.panelDelegates.removeValue(forKey: viewModel.id)
                self?.slots.removeValue(forKey: viewModel.id)
                if appViewModel.isSingleTimerMode, appViewModel.activeTimerID == viewModel.id {
                    appViewModel.activeTimerID = nil
                    appViewModel.stopBroadcast()
                }
            },
            onMove: { [weak self] origin in
                self?.lastActiveOrigin = origin
            }
        )
        panel.delegate = panelDelegate
        
        panels[viewModel.id] = panel
        panelDelegates[viewModel.id] = panelDelegate
        panel.makeKeyAndOrderFront(nil)
    }
    
    func closeTimer(_ id: UUID, in appViewModel: AppViewModel) {
        tearDown(id)
        if appViewModel.isSingleTimerMode, appViewModel.activeTimerID == id {
            appViewModel.activeTimerID = nil
            appViewModel.stopBroadcast()
        }
    }
    
    /// Closes a panel and forgets its bookkeeping, without touching which timer
    /// the app considers active.
    private func tearDown(_ id: UUID) {
        if let panel = panels[id] {
            panel.delegate = nil
            panel.close()
        }
        panels.removeValue(forKey: id)
        panelDelegates.removeValue(forKey: id)
        slots.removeValue(forKey: id)
    }
    
    /// Brings the given timer's floating panel to the front, without stealing key focus
    /// away from the main app window any more than necessary.
    func focusTimer(_ id: UUID) {
        guard let panel = panels[id] else { return }
        // Focusing a timer makes it the active one, so its spot becomes the one
        // the next timer will reuse.
        lastActiveOrigin = panel.frame.origin
        panel.makeKeyAndOrderFront(nil)
    }
}

class PanelDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    private let onMove: (NSPoint) -> Void
    
    init(onClose: @escaping () -> Void, onMove: @escaping (NSPoint) -> Void) {
        self.onClose = onClose
        self.onMove = onMove
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onMove(window.frame.origin)
    }
}
