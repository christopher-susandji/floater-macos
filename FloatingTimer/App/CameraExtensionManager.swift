//
//  CameraExtensionManager.swift
//  Floater
//
//  Created by Christopher Susandji on 07/09/26.
//

import Foundation
import SystemExtensions

/// Requests installation/activation of the FloaterCamera extension so the
/// virtual camera becomes available system-wide. The user must approve the
/// prompt and, if macOS requires, allow it in System Settings → Privacy & Security.
@MainActor
final class CameraExtensionManager: NSObject {
    static let shared = CameraExtensionManager()

    private var pendingRequest: OSSystemExtensionRequest?

    /// The bundle identifier of the camera extension target. Must match the
    /// extension's CFBundleIdentifier.
    private let extensionIdentifier = "me.christophersusandji.Floater.FloaterCamera"

    func install() {
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

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {}

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {}

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        pendingRequest = nil
    }
}
