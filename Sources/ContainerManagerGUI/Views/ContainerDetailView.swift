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

struct ContainerDetailView: View {
    var record: ContainerRecord
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @State private var selectedTab = DetailTab.overview

    enum DetailTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case logs = "Logs"
        case terminal = "Terminal"
        case network = "Network"
        case mounts = "Mounts"
        case permissions = "Permissions"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .logs: return "text.alignleft"
            case .terminal: return "terminal"
            case .network: return "network"
            case .mounts: return "externaldrive"
            case .permissions: return "lock.shield"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            containerHeader

            Divider()

            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(DetailTab.allCases) { tab in
                        DetailTabButton(tab: tab, selected: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 38)
            .background(.bar)

            Divider()

            // Content
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(record.displayName)
    }

    // MARK: - Header

    private var containerHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(record.status.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(record.status.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    StatusBadge(status: record.status)
                }
                Text(record.imageReference)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("ID: \(record.id)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if record.status == .running {
                    Button {
                        Task { try? await containerService.stop(id: record.id) }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else if record.status == .stopped {
                    Button {
                        // Re-launch not yet implemented in this iteration
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                    .disabled(true)
                }

                Menu {
                    Button {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(record.id, forType: .string)
                    } label: {
                        Label("Copy Container ID", systemImage: "doc.on.clipboard")
                    }
                    if let ip = record.ipAddress {
                        Button {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(ip, forType: .string)
                        } label: {
                            Label("Copy IP Address", systemImage: "network")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        Task { try? await containerService.delete(id: record.id) }
                    } label: {
                        Label("Delete Container", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            OverviewTab(record: record)
        case .logs:
            LogsTab(record: record)
        case .terminal:
            TerminalTab(record: record)
                .environment(containerService)
        case .network:
            NetworkTab(record: record)
        case .mounts:
            MountsTab(record: record)
        case .permissions:
            PermissionsDetailTab(record: record)
        }
    }
}

// MARK: - Detail Tab Button

struct DetailTabButton: View {
    let tab: ContainerDetailView.DetailTab
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selected ? Color.accentColor.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Overview Tab

struct OverviewTab: View {
    var record: ContainerRecord

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                InfoSection(title: "Container") {
                    InfoRow(label: "ID", value: record.id, monospace: true)
                    InfoRow(label: "Name", value: record.name)
                    InfoRow(label: "Image", value: record.imageReference)
                    InfoRow(label: "Status", value: record.status.rawValue)
                    InfoRow(label: "Created", value: record.createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                InfoSection(title: "Resources") {
                    InfoRow(label: "CPUs", value: "\(record.cpus)")
                    InfoRow(label: "Memory", value: record.memoryFormatted)
                    InfoRow(label: "Filesystem", value: record.fsSizeFormatted)
                    InfoRow(label: "Read-Only", value: record.readOnly ? "Yes" : "No")
                }

                InfoSection(title: "Process") {
                    InfoRow(label: "Command", value: record.command.isEmpty ? "(image default)" : record.command.joined(separator: " "), monospace: true)
                    InfoRow(label: "Working Dir", value: record.workingDirectory, monospace: true)
                    InfoRow(label: "Init Process", value: record.useInit ? "Enabled" : "Disabled")
                    InfoRow(label: "Capabilities", value: record.capabilityPreset.rawValue)
                }

                if record.rosettaEnabled {
                    InfoSection(title: "Compatibility") {
                        InfoRow(label: "Rosetta 2", value: "Enabled (x86_64 emulation)")
                    }
                }

                if !record.environmentVariables.isEmpty {
                    InfoSection(title: "Environment Variables") {
                        ForEach(record.environmentVariables, id: \.self) { env in
                            Text(env)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 1)
                        }
                    }
                }

                if let err = record.errorMessage {
                    InfoSection(title: "Last Error") {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Logs Tab

struct LogsTab: View {
    var record: ContainerRecord
    @State private var autoScroll = true
    @State private var proxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Container Logs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(record.logs, forType: .string)
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .buttonStyle(.plain)
                .help("Copy logs")
                Button {
                    // Clear logs
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .help("Clear logs")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    if record.logs.isEmpty {
                        Text("No logs yet…")
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(20)
                    } else {
                        Text(record.logs)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .id("logBottom")
                    }
                }
                .background(Color(.textBackgroundColor))
                .onChange(of: record.logs) {
                    if autoScroll {
                        withAnimation {
                            scrollProxy.scrollTo("logBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Terminal Tab

struct TerminalTab: View {
    var record: ContainerRecord
    @Environment(ContainerService.self) private var containerService
    @State private var commandInput = ""
    @State private var terminalOutput = ""
    @State private var isExecuting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                Text("Interactive Exec")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if record.status != .running {
                    Text("Container not running")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)

            Divider()

            ScrollView {
                Text(terminalOutput.isEmpty ? "Enter a command below and press Return to execute it inside the container." : terminalOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(terminalOutput.isEmpty ? .tertiary : .primary)
                    .padding(12)
            }
            .background(Color(.textBackgroundColor))

            Divider()

            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField("Enter command…", text: $commandInput)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .disabled(record.status != .running || isExecuting)
                    .onSubmit { executeCommand() }

                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("Run") { executeCommand() }
                        .buttonStyle(.borderedProminent)
                        .disabled(commandInput.isEmpty || record.status != .running)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private func executeCommand() {
        guard !commandInput.isEmpty, record.status == .running else { return }
        let cmd = commandInput
        commandInput = ""
        isExecuting = true
        terminalOutput += "\n$ \(cmd)\n"

        Task {
            do {
                let output = try await containerService.execInContainer(
                    id: record.id,
                    command: ["/bin/sh", "-c", cmd]
                )
                await MainActor.run {
                    terminalOutput += output
                    isExecuting = false
                }
            } catch {
                await MainActor.run {
                    terminalOutput += "Error: \(error.localizedDescription)\n"
                    isExecuting = false
                }
            }
        }
    }
}

// MARK: - Network Tab

struct NetworkTab: View {
    var record: ContainerRecord

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if record.networkEnabled {
                    InfoSection(title: "Network Interface") {
                        InfoRow(label: "IP Address", value: record.ipAddress ?? "N/A", monospace: true)
                        InfoRow(label: "Subnet", value: record.networkSubnet ?? "N/A", monospace: true)
                        InfoRow(label: "MAC Address", value: record.macAddress ?? "N/A", monospace: true)
                        InfoRow(label: "Mode", value: "vmnet (Shared)")
                    }

                    InfoSection(title: "Host Communication") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The container can reach the host via the gateway IP (first address in the subnet, e.g. 192.168.64.1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let ip = record.ipAddress {
                                HStack {
                                    Text("From host, reach container at:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(ip)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quinary, in: RoundedRectangle(cornerRadius: 4))
                                    Button {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.setString(ip, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.clipboard")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    InfoSection(title: "Inter-Container Communication") {
                        Text("Containers on the same vmnet network can communicate directly using their assigned IP addresses. No port mapping required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView(
                        "Network Disabled",
                        systemImage: "slash.circle",
                        description: Text("This container was launched without network access.")
                    )
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Mounts Tab

struct MountsTab: View {
    var record: ContainerRecord

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                InfoSection(title: "Root Filesystem") {
                    InfoRow(label: "Format", value: "EXT4 block device")
                    InfoRow(label: "Size", value: record.fsSizeFormatted)
                    InfoRow(label: "Mode", value: record.readOnly ? "Read-only" : "Read-write")
                }

                if record.mounts.isEmpty {
                    ContentUnavailableView(
                        "No Shared Volumes",
                        systemImage: "externaldrive",
                        description: Text("No host directories are shared into this container.")
                    )
                } else {
                    InfoSection(title: "Shared Directories (virtiofs)") {
                        ForEach(record.mounts) { mount in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.blue)
                                        Text(mount.hostPath)
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                    HStack {
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Text(mount.containerPath)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if mount.readOnly {
                                    Text("ro")
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Permissions Detail Tab

struct PermissionsDetailTab: View {
    var record: ContainerRecord

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                InfoSection(title: "Capability Profile") {
                    HStack {
                        Image(systemName: record.capabilityPreset.icon)
                            .foregroundStyle(.accentColor)
                        VStack(alignment: .leading) {
                            Text(record.capabilityPreset.rawValue)
                                .fontWeight(.medium)
                            Text(record.capabilityPreset.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if record.capabilityPreset == .custom && !record.customCapabilities.isEmpty {
                    InfoSection(title: "Enabled Capabilities") {
                        let cols = [GridItem(.adaptive(minimum: 160))]
                        LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                            ForEach(record.customCapabilities, id: \.self) { cap in
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text(cap)
                                        .font(.caption)
                                        .monospaced()
                                }
                            }
                        }
                    }
                }

                InfoSection(title: "Security Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        SecurityNoteRow(
                            icon: "lock.shield.fill",
                            color: .blue,
                            text: "Each container runs in an isolated virtual machine with its own kernel boundary."
                        )
                        SecurityNoteRow(
                            icon: "network.badge.shield.half.filled",
                            color: .green,
                            text: "Container networking uses vmnet with dedicated IP addresses — no port conflicts."
                        )
                        SecurityNoteRow(
                            icon: "cpu.fill",
                            color: .orange,
                            text: "Resource limits (CPU, memory) are enforced at the VM hypervisor level."
                        )
                    }
                }
            }
            .padding(20)
        }
    }
}

struct SecurityNoteRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Shared Info Components

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(12)
            .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var monospace: Bool = false

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            if monospace {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
            } else {
                Text(value)
                    .font(.caption)
            }
            Spacer()
        }
    }
}
