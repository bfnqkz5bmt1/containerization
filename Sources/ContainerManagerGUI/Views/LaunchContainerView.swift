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

struct LaunchContainerView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @Environment(\.dismiss) private var dismiss

    @State private var config: LaunchConfig
    @State private var selectedSection = LaunchSection.basic
    @State private var isLaunching = false
    @State private var errorMessage: String?
    @State private var newEnvKey = ""
    @State private var newEnvValue = ""
    @State private var newHostPath = ""
    @State private var newContainerPath = ""
    @State private var newNameserver = ""
    @State private var customCapInput = ""

    enum LaunchSection: String, CaseIterable, Identifiable {
        case basic = "Basic"
        case resources = "Resources"
        case network = "Network"
        case volumes = "Volumes"
        case environment = "Environment"
        case process = "Process"
        case permissions = "Permissions"
        case advanced = "Advanced"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .basic: return "shippingbox"
            case .resources: return "cpu"
            case .network: return "network"
            case .volumes: return "externaldrive"
            case .environment: return "list.bullet.rectangle"
            case .process: return "terminal"
            case .permissions: return "lock.shield"
            case .advanced: return "gearshape.2"
            }
        }
    }

    init() {
        // _config will be set with real appState in body; placeholder init
        _config = State(initialValue: LaunchConfig(defaults: AppState()))
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            // Sheet header
            HStack {
                Image(systemName: "shippingbox.fill")
                    .font(.title2)
                    .foregroundStyle(.accentColor)
                VStack(alignment: .leading) {
                    Text("Launch Container")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Configure and start a new Linux container")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Launch") { launchContainer() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLaunching || config.imageReference.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
            .background(.regularMaterial)

            Divider()

            HSplitView {
                // Left nav
                List(LaunchSection.allCases, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .frame(width: 160)

                // Right content
                ScrollView {
                    Group {
                        switch selectedSection {
                        case .basic:         basicSection
                        case .resources:     resourcesSection
                        case .network:       networkSection
                        case .volumes:       volumesSection
                        case .environment:   environmentSection
                        case .process:       processSection
                        case .permissions:   permissionsSection
                        case .advanced:      advancedSection
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let err = errorMessage {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                    Button {
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(.red.opacity(0.08))
            }

            if isLaunching {
                ProgressView("Launching container…")
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .frame(width: 680, height: 540)
        .task {
            // Re-initialize config with actual appState defaults
            config = LaunchConfig(defaults: appState)
        }
    }

    // MARK: - Basic Section

    private var basicSection: some View {
        FormSection(title: "Container Identity") {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Name") {
                    TextField("my-container", text: $config.name)
                        .textFieldStyle(.roundedBorder)
                }
                LabeledContent("Container ID") {
                    TextField("Auto-generated", text: $config.id)
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                }
                LabeledContent("Image") {
                    HStack {
                        TextField("docker.io/library/alpine:latest", text: $config.imageReference)
                            .textFieldStyle(.roundedBorder)
                            .monospaced()
                        if !containerService.images.isEmpty {
                            Menu("Select") {
                                ForEach(containerService.images) { img in
                                    Button(img.displayName) {
                                        config.imageReference = img.reference
                                    }
                                }
                            }
                            .menuStyle(.borderedButton)
                        }
                    }
                }

                Text("Supports any OCI-compliant image reference, e.g. docker.io/library/ubuntu:22.04 or ghcr.io/my-org/my-app:latest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(spacing: 20) {
            FormSection(title: "Compute") {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("CPUs") {
                        HStack {
                            Slider(value: Binding(
                                get: { Double(config.cpus) },
                                set: { config.cpus = max(1, Int($0)) }
                            ), in: 1...16, step: 1)
                            .frame(width: 200)
                            Text("\(config.cpus)")
                                .monospacedDigit()
                                .frame(width: 30)
                            Stepper("", value: $config.cpus, in: 1...16)
                                .labelsHidden()
                        }
                    }

                    LabeledContent("Memory") {
                        HStack {
                            Picker("", selection: $config.memoryMB) {
                                Text("256 MB").tag(UInt64(256))
                                Text("512 MB").tag(UInt64(512))
                                Text("1 GB").tag(UInt64(1024))
                                Text("2 GB").tag(UInt64(2048))
                                Text("4 GB").tag(UInt64(4096))
                                Text("8 GB").tag(UInt64(8192))
                                Text("16 GB").tag(UInt64(16384))
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                        }
                    }
                }
            }

            FormSection(title: "Storage") {
                LabeledContent("Filesystem Size") {
                    Picker("", selection: $config.fsSizeMB) {
                        Text("1 GB").tag(UInt64(1024))
                        Text("2 GB").tag(UInt64(2048))
                        Text("4 GB").tag(UInt64(4096))
                        Text("8 GB").tag(UInt64(8192))
                        Text("16 GB").tag(UInt64(16384))
                        Text("32 GB").tag(UInt64(32768))
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        VStack(spacing: 20) {
            FormSection(title: "Network") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Networking", isOn: $config.networkEnabled)

                    if config.networkEnabled {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            if #available(macOS 26, *) {
                                Label("Using vmnet shared networking", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Each container receives a dedicated IP on the host-accessible subnet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Label("vmnet requires macOS 26+. Networking unavailable.", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                        }
                    }
                }
            }

            if config.networkEnabled {
                FormSection(title: "DNS") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Nameservers (optional — defaults to gateway IP)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(config.nameservers.indices, id: \.self) { idx in
                            HStack {
                                Text(config.nameservers[idx])
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Button {
                                    config.nameservers.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack {
                            TextField("e.g. 1.1.1.1", text: $newNameserver)
                                .textFieldStyle(.roundedBorder)
                                .monospaced()
                                .onSubmit { addNameserver() }
                            Button("Add", action: addNameserver)
                                .disabled(newNameserver.isEmpty)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Volumes Section

    private var volumesSection: some View {
        FormSection(title: "Shared Directories (virtiofs)") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Share host directories into the container using virtio-fs. Changes are visible in real-time on both sides.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if config.mounts.isEmpty {
                    Text("No volumes configured.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(config.mounts.indices, id: \.self) { idx in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.fill").foregroundStyle(.blue).font(.caption)
                                    Text(config.mounts[idx].hostPath).font(.system(.caption, design: .monospaced))
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                    Text(config.mounts[idx].containerPath).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Toggle("ro", isOn: $config.mounts[idx].readOnly)
                                .font(.caption)
                            Button {
                                config.mounts.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                    Divider()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField("Host path", text: $newHostPath)
                            .textFieldStyle(.roundedBorder)
                            .monospaced()
                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                newHostPath = url.path
                            }
                        } label: {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                    }
                    HStack {
                        TextField("Container path (e.g. /data)", text: $newContainerPath)
                            .textFieldStyle(.roundedBorder)
                            .monospaced()
                        Button("Add Volume") {
                            addMount()
                        }
                        .disabled(newHostPath.isEmpty || newContainerPath.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Environment Section

    private var environmentSection: some View {
        FormSection(title: "Environment Variables") {
            VStack(alignment: .leading, spacing: 10) {
                Text("These are appended to the image's default environment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if config.environmentVariables.isEmpty {
                    Text("No custom environment variables.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(config.environmentVariables.indices, id: \.self) { idx in
                        HStack {
                            Text(config.environmentVariables[idx])
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Button {
                                config.environmentVariables.remove(at: idx)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Divider()
                }

                HStack {
                    TextField("KEY", text: $newEnvKey)
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                        .frame(width: 140)
                    Text("=")
                        .foregroundStyle(.secondary)
                    TextField("value", text: $newEnvValue)
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                    Button("Add") { addEnvVar() }
                        .disabled(newEnvKey.isEmpty)
                }
            }
        }
    }

    // MARK: - Process Section

    private var processSection: some View {
        VStack(spacing: 20) {
            FormSection(title: "Command") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Override the image's default entrypoint and command. Leave empty to use image defaults.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LabeledContent("Command") {
                        TextField("e.g. /bin/sh -c 'echo hello'", text: Binding(
                            get: { config.command.joined(separator: " ") },
                            set: { val in
                                config.command = val.isEmpty ? [] : val.components(separatedBy: " ").filter { !$0.isEmpty }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                    }

                    LabeledContent("Working Dir") {
                        TextField("/", text: $config.workingDirectory)
                            .textFieldStyle(.roundedBorder)
                            .monospaced()
                    }
                }
            }

            FormSection(title: "User") {
                Text("User is determined by the image configuration by default. You can override in environment variables or capability settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Permissions Section

    private var permissionsSection: some View {
        VStack(spacing: 20) {
            FormSection(title: "Capability Preset") {
                VStack(spacing: 8) {
                    ForEach(CapabilityPreset.allCases) { preset in
                        Button {
                            config.capabilityPreset = preset
                        } label: {
                            HStack {
                                Image(systemName: preset.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(config.capabilityPreset == preset ? .accentColor : .secondary)
                                VStack(alignment: .leading) {
                                    Text(preset.rawValue)
                                        .fontWeight(config.capabilityPreset == preset ? .semibold : .regular)
                                    Text(preset.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if config.capabilityPreset == preset {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accentColor)
                                }
                            }
                            .padding(10)
                            .background(
                                config.capabilityPreset == preset ? Color.accentColor.opacity(0.08) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if config.capabilityPreset == .custom {
                FormSection(title: "Custom Capabilities") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Linux capability names (e.g. CAP_NET_ADMIN, CAP_SYS_PTRACE).")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(config.customCapabilities, id: \.self) { cap in
                            HStack {
                                Text(cap)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                                Button {
                                    config.customCapabilities.removeAll { $0 == cap }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        HStack {
                            TextField("CAP_NET_ADMIN", text: $customCapInput)
                                .textFieldStyle(.roundedBorder)
                                .monospaced()
                                .onSubmit { addCustomCap() }
                            Button("Add") { addCustomCap() }
                                .disabled(customCapInput.isEmpty)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(spacing: 20) {
            FormSection(title: "Compatibility") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $config.rosettaEnabled) {
                        VStack(alignment: .leading) {
                            Text("Enable Rosetta 2 (x86_64 emulation)")
                            Text("Allows running linux/amd64 container images on Apple silicon via Rosetta 2.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            FormSection(title: "Init System") {
                Toggle(isOn: $config.useInit) {
                    VStack(alignment: .leading) {
                        Text("Use init process")
                        Text("Enables signal forwarding and zombie process reaping via a lightweight init.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            FormSection(title: "Filesystem") {
                Toggle(isOn: $config.readOnly) {
                    VStack(alignment: .leading) {
                        Text("Read-only root filesystem")
                        Text("Mounts the container root filesystem in read-only mode for extra security.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func launchContainer() {
        isLaunching = true
        errorMessage = nil

        let cfg = config
        Task {
            do {
                try await containerService.launch(config: cfg)
                await MainActor.run {
                    isLaunching = false
                    dismiss()
                    appState.selectedSidebarItem = .containers
                    appState.selectedContainerID = cfg.id
                }
            } catch {
                await MainActor.run {
                    isLaunching = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func addEnvVar() {
        guard !newEnvKey.isEmpty else { return }
        config.environmentVariables.append("\(newEnvKey)=\(newEnvValue)")
        newEnvKey = ""
        newEnvValue = ""
    }

    private func addMount() {
        guard !newHostPath.isEmpty, !newContainerPath.isEmpty else { return }
        config.mounts.append(MountRecord(hostPath: newHostPath, containerPath: newContainerPath))
        newHostPath = ""
        newContainerPath = ""
    }

    private func addNameserver() {
        guard !newNameserver.isEmpty else { return }
        config.nameservers.append(newNameserver)
        newNameserver = ""
    }

    private func addCustomCap() {
        let cap = customCapInput.uppercased()
        guard !cap.isEmpty, !config.customCapabilities.contains(cap) else { return }
        config.customCapabilities.append(cap)
        customCapInput = ""
    }
}

// MARK: - Form Section

struct FormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
                .padding(14)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
