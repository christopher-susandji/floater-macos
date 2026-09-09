//
//  SettingsView.swift
//  Floater
//
//  Created by Christopher Susandji on 08/09/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var cameraExtensionManager = CameraExtensionManager.shared
    @State private var appViewModel = AppViewModel.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { cameraExtensionManager.isInstalled },
                    set: { enabled in
                        if enabled {
                            cameraExtensionManager.install()
                        } else {
                            cameraExtensionManager.uninstall()
                        }
                    }
                )) {
                    Text("Add Floater as Camera Extension")
                }
                Text("Installs Floater as a virtual camera so you can insert a timer into Keynote as a live video source.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if cameraExtensionManager.isAwaitingApproval {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Floater is waiting for your approval in System Settings. Approve it there, then this switch turns on automatically.")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button("Open System Settings…") {
                            cameraExtensionManager.openSystemExtensionSettings()
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }

            Section {
                ColorPicker(
                    "Broadcast background",
                    selection: Binding(
                        get: { appViewModel.broadcastBackgroundColor },
                        set: { appViewModel.broadcastBackgroundColor = $0 }
                    ),
                    supportsOpacity: false
                )
                Text("The solid backdrop painted behind a timer in the live-video feed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Changes apply to the next broadcast and to any timer currently broadcasting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            cameraExtensionManager.refreshInstalledState()
        }
    }
}

#Preview {
    SettingsView()
}
