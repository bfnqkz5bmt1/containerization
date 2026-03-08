//===----------------------------------------------------------------------===//
// Copyright © 2025-2026 Apple Inc. and the Containerization project authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//===----------------------------------------------------------------------===//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @State private var selectedSection = SettingsSection.runtime

    enum SettingsSection: String, CaseIterable {
        case runtime = "Runtime"
        case defaults = "Defaults"
        case about = "About"
    }

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $selectedSection) {
            runtimeTab
                .tabItem { Label("Runtime", systemImage: "gearshape") }
                .tag(SettingsSection.runtime)

            defaultsTab
                .tabItem { Label("Defaults", systemImage: "slider.horizontal.3") }
                .tag(SettingsSection.defaults)

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsSection.about)
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }

    // MARK: - Runtime Tab

    private var runtimeTab: some View {
        @Bindable var appState = appState

        return Form {
            Section("Kernel") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Path to Linux kernel binary", text: $appState.kernelPath)
                            .textFieldStyle(.roundedBorder)
                            .monospaced()

                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = true
                            panel.canChooseDirectories = false
                            panel.allowsMultipleSelection = false
                            panel.title = "Select Linux Kernel Binary"
                            if panel.runModal() == .OK, let url = panel.url {
                                appState.kernelPath = url.path
                            }
                        }
                    }

                    if appState.kernelPath.isEmpty {
                        Label("No kernel configured. Download a kernel from the Apple containerization project.", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if !FileManager.default.fileExists(atPath: appState.kernelPath) {
                        Label("Kernel not found at path: \(appState.kernelPath)", systemImage: "xmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Label("Kernel found.", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button("Download Kernel…") {
                        NSWorkspace.shared.open(
                            URL(string: "https://github.com/apple/containerization/releases")!
                        )
                    }
                    .font(.caption)
                }
            }

            Section("Init Filesystem") {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("vminit:latest", text: $appState.initfsReference)
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                    Text("OCI image reference for the virtual machine init filesystem (vminitd). Usually vminit:latest.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Status") {
                if containerService.isInitializing {
                    HStack {
                        ProgressView().scaleEffect(0.7)
                        Text("Initializing runtime…")
                            .font(.callout)
                    }
                } else if let err = containerService.initError {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Runtime initialization failed", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                        Button("Retry") {
                            Task { await containerService.initialize(appState: appState) }
                        }
                        .buttonStyle(.bordered)
                    }
                } else if containerService.isInitialized {
                    Label("Runtime initialized and ready.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Initialize Runtime") {
                        Task { await containerService.initialize(appState: appState) }
                    }
                    .disabled(!appState.isKernelConfigured)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Defaults Tab

    private var defaultsTab: some View {
        @Bindable var appState = appState

        return Form {
            Section("Default Resources") {
                Stepper("CPUs: \(appState.defaultCPUs)", value: $appState.defaultCPUs, in: 1...16)
                Picker("Memory", selection: $appState.defaultMemoryMB) {
                    Text("256 MB").tag(UInt64(256))
                    Text("512 MB").tag(UInt64(512))
                    Text("1 GB").tag(UInt64(1024))
                    Text("2 GB").tag(UInt64(2048))
                    Text("4 GB").tag(UInt64(4096))
                    Text("8 GB").tag(UInt64(8192))
                }
            }

            Section("Default Network") {
                TextField("Subnet CIDR", text: $appState.defaultSubnet)
                    .textFieldStyle(.roundedBorder)
                    .monospaced()
                Text("Default subnet for vmnet networking (e.g. 192.168.64.0/24)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("Container Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("macOS GUI for Apple Containerization")
                    .foregroundStyle(.secondary)
                Text("Built on Apple's open-source containerization framework.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/apple/containerization")!)
                    .buttonStyle(.link)
                Link("Documentation", destination: URL(string: "https://developer.apple.com/documentation")!)
                    .buttonStyle(.link)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                AboutRow(label: "Framework", value: "Apple Containerization")
                AboutRow(label: "Virtualization", value: "Apple Virtualization.framework")
                AboutRow(label: "Networking", value: "vmnet (macOS 26+)")
                AboutRow(label: "Image Format", value: "OCI v1")
                AboutRow(label: "Kernel Min", value: "Linux 6.14.9")
                AboutRow(label: "Platform", value: "macOS 15+, Apple Silicon")
            }
            .padding()
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AboutRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}
