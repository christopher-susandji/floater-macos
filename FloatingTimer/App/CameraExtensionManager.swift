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

/// Manages the FloaterCamera system extension: activation, deactivation, and
/// reflecting whether it's currently installed. Activation is user-initiated
/// (from Settings), not automatic, so the system approval prompt only appears
/// when the user asks for it.
@MainActor
@Observable
final class CameraExtensionManager: NSObject {
    static let shared = CameraExtensionManager()

    private var pendingRequest: OSSystemExtensionRequest?

    /// The bundle identifier of the camera extension target. Must match the
    /// extension's CFBundleIdentifier.
    private let extensionIdentifier = "me.christophersusandji.Floater.FloaterCamera"

    /// Whether the camera extension is currently active, determined by whether
    /// its "Floater" virtual camera is enumerable. Sandbox-safe (spawning
    /// `systemextensionsctl` isn't possible from an App Store app).
    private(set) var isInstalled: Bool = false

    override private init() {
        super.init()
        refreshInstalledState()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceListChanged),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Re-reads whether the Floater camera is present.
    func refreshInstalledState() {
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )
        isInstalled = session.devices.contains { $0.localizedName == "Floater" }
    }

    @objc private func deviceListChanged() {
        refreshInstalledState()
    }

    /// Activates the camera extension, presenting the system approval prompt.
    func install() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: extensionIdentifier,
            queue: .main
        )
        request.delegate = self
        pendingRequest = request
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Deactivates the camera extension.
    func uninstall() {
        let request = OSSystemExtensionRequest.deactivationRequest(
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

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {}

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        pendingRequest = nil
        refreshInstalledState()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        pendingRequest = nil
        refreshInstalledState()
    }
}
