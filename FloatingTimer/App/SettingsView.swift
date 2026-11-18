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

    /// The timer the camera would show: single mode pins it, otherwise the row's
    /// camera button picks it, falling back to the newest timer so the switch is
    /// still usable before anything has been broadcast. The camera can only carry
    /// one timer either way.
    private var cameraTargetID: UUID? {
        if appViewModel.isSingleTimerMode {
            return appViewModel.activeTimerID
        }
        return appViewModel.activeTimerID
            ?? appViewModel.broadcastTimerID
            ?? appViewModel.timerViewModels.last?.id
    }

    private var broadcastBinding: Binding<Bool> {
        Binding(
            get: { appViewModel.isBroadcasting },
            set: { broadcasting in
                if broadcasting, let id = cameraTargetID {
                    appViewModel.startBroadcast(timerID: id)
                } else {
                    appViewModel.stopBroadcast()
                }
            }
        )
    }

    private var cameraCaption: String {
        appViewModel.isSingleTimerMode
            ? "The pinned timer is what the desktop and the camera show. Pinning another timer moves both."
            : "Pin a timer to be the one the camera shows. The other timers keep their own floating panels."
    }

    var body: some View {
        Form {
            Section {
                if cameraExtensionManager.isInstalled {
                    Toggle(isOn: broadcastBinding) {
                        Text("Floater as Camera Input")
                    }
                    .disabled(!appViewModel.isBroadcasting && cameraTargetID == nil)
                    Text(cameraCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        cameraExtensionManager.install()
                    } label: {
                        Text("Add Floater as Camera Extension")
                    }
                    Text("Installs Floater as a virtual camera so you can insert a timer into Keynote as a live video source.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastError = cameraExtensionManager.lastError {
                        Label {
                            Text(lastError)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .padding(.top, 4)
                    }

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
            }

            Section {
                Toggle(isOn: Binding(
                    get: { appViewModel.isSingleTimerMode },
                    set: { appViewModel.setSingleTimerMode($0) }
                )) {
                    Text("Show one timer at a time")
                }
                Text("Keeps a single floating timer on the desktop. Pin a timer in the list to swap which one is shown. Switching on Floater as Camera Input turns this on, since the camera can only show one timer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Desktop")
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
