//
//  CameraExtensionManager.swift
//  Floater
//
//  Created by Christopher Susandji on 07/09/26.
//

import Foundation
import SystemExtensions
import AVFoundation
import Observation
import AppKit

/// Manages the FloaterCamera system extension: activation, deactivation, and
/// reflecting whether it's currently installed. Activation is user-initiated
/// (from Settings), not automatic, so the system approval prompt only appears
/// when the user asks for it.
@MainActor
@Observable
final class CameraExtensionManager: NSObject {
    static let shared = CameraExtensionManager()

    private var pendingRequest: OSSystemExtensionRequest?
    private var refreshTimer: Timer?

    /// The bundle identifier of the camera extension target. Must match the
    /// extension's CFBundleIdentifier.
    private let extensionIdentifier = "me.christophersusandji.Floater.FloaterCamera"

    /// Whether the camera extension is currently active, determined by whether
    /// its "Floater" virtual camera is enumerable. Sandbox-safe (spawning
    /// `systemextensionsctl` isn't possible from an App Store app).
    private(set) var isInstalled: Bool = false

    /// True while an activation request is queued and waiting for the user to
    /// approve it in System Settings → Privacy & Security. macOS won't re-show
    /// the approval prompt for a request that's already pending, so we surface
    /// this state in the UI instead of silently doing nothing on a re-click.
    private(set) var isAwaitingApproval: Bool = false

    /// The last system-extension request failure, shown in Settings so failures
    /// (e.g. the app not being installed in /Applications) aren't silent.
    private(set) var lastError: String?

    override private init() {
        super.init()
        refreshInstalledState()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: AVCaptureDevice.wasConnectedNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: AVCaptureDevice.wasDisconnectedNotification,
            object: nil
        )
        // Re-check when the app comes to the foreground (e.g. after the user
        // approves in System Settings), since the activation completes outside
        // this process and may not deliver a device-connect notification.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        startRefreshTimerIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Polls for the camera while it isn't installed, so the toggle flips on
    /// right after the extension activates — even if no system notification
    /// reaches this process. Stops itself once installed.
    private func startRefreshTimerIfNeeded() {
        guard refreshTimer == nil, !isInstalled else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshInstalledState()
                if self.isInstalled {
                    self.refreshTimer?.invalidate()
                    self.refreshTimer = nil
                }
            }
        }
    }

    /// Re-reads whether the Floater camera is present.
    func refreshInstalledState() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        isInstalled = session.devices.contains { $0.localizedName == "Floater" }
        if isInstalled {
            isAwaitingApproval = false
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    @objc private func deviceListChanged() {
        refreshInstalledState()
    }

    /// Opens the macOS pane where the pending extension approval lives, so the
    /// user can click "Allow". No-op if the deep link can't be formed.
    func openSystemExtensionSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Activates the camera extension, presenting the system approval prompt.
    func install() {
        lastError = nil
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        pendingRequest = request
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}

extension CameraExtensionManager: OSSystemExtensionRequestDelegate {
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        isAwaitingApproval = true
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        pendingRequest = nil
        isAwaitingApproval = false
        lastError = nil
        refreshInstalledState()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        pendingRequest = nil
        isAwaitingApproval = false
        lastError = error.localizedDescription
        refreshInstalledState()
    }
}
