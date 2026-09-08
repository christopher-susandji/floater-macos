//
//  SettingsView.swift
//  Floater
//
//  Created by Christopher Susandji on 08/09/26.
//

import SwiftUI

struct SettingsView: View {
    @State private var cameraExtensionManager = CameraExtensionManager.shared

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
