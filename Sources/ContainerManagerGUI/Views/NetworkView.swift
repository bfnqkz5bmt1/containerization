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

struct NetworkView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @State private var selectedTab = NetworkTab.topology

    enum NetworkTab: String, CaseIterable {
        case topology = "Topology"
        case info = "Configuration"
        case communication = "Communication"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(NetworkTab.allCases, id: \.rawValue) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            switch selectedTab {
            case .topology:
                NetworkTopologyView()
                    .environment(appState)
                    .environment(containerService)
            case .info:
                NetworkConfigView()
                    .environment(appState)
            case .communication:
                NetworkCommunicationGuide()
                    .environment(containerService)
            }
        }
        .navigationTitle("Network")
    }
}

// MARK: - Topology View

struct NetworkTopologyView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService

    private var runningContainers: [ContainerRecord] {
        containerService.containers.filter { $0.status == .running && $0.networkEnabled }
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Canvas { context, size in
                drawTopology(context: context, size: size)
            }
            .frame(
                width: max(600, CGFloat(runningContainers.count * 160 + 200)),
                height: 500
            )
            .overlay(topologyOverlay)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Group {
                if runningContainers.isEmpty {
                    ContentUnavailableView(
                        "No Running Containers",
                        systemImage: "network",
                        description: Text("Launch containers with networking to see the topology.")
                    )
                }
            }
        )
    }

    private func drawTopology(context: GraphicsContext, size: CGSize) {
        guard !runningContainers.isEmpty else { return }

        let centerX = size.width / 2
        let centerY = size.height / 2
        let nodeRadius: CGFloat = 36
        let hostRadius: CGFloat = 48

        // Draw host node (macOS)
        let hostRect = CGRect(
            x: centerX - hostRadius,
            y: 40,
            width: hostRadius * 2,
            height: hostRadius * 2
        )
        context.fill(
            Path(ellipseIn: hostRect),
            with: .color(.blue.opacity(0.15))
        )
        context.stroke(
            Path(ellipseIn: hostRect),
            with: .color(.blue),
            lineWidth: 2
        )

        // Draw network backbone (horizontal line)
        let backboneY = 200.0
        let backboneStart = CGPoint(x: 80, y: backboneY)
        let backboneEnd = CGPoint(x: size.width - 80, y: backboneY)
        var backbonePath = Path()
        backbonePath.move(to: backboneStart)
        backbonePath.addLine(to: backboneEnd)
        context.stroke(backbonePath, with: .color(.gray.opacity(0.4)), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))

        // Draw host-to-backbone connection
        var hostLine = Path()
        hostLine.move(to: CGPoint(x: centerX, y: 40 + hostRadius * 2))
        hostLine.addLine(to: CGPoint(x: centerX, y: backboneY))
        context.stroke(hostLine, with: .color(.blue.opacity(0.5)), lineWidth: 1.5)

        // Draw containers
        let spacing = (size.width - 160) / CGFloat(max(runningContainers.count, 1))
        for (i, container) in runningContainers.enumerated() {
            let containerX = 80 + spacing * CGFloat(i) + spacing / 2
            let containerY: CGFloat = 330

            // Backbone-to-container line
            var connLine = Path()
            connLine.move(to: CGPoint(x: containerX, y: backboneY))
            connLine.addLine(to: CGPoint(x: containerX, y: containerY - nodeRadius))
            context.stroke(
                connLine,
                with: .color(container.status.color.opacity(0.5)),
                lineWidth: 1.5
            )

            // Container node
            let nodeRect = CGRect(
                x: containerX - nodeRadius,
                y: containerY - nodeRadius,
                width: nodeRadius * 2,
                height: nodeRadius * 2
            )
            context.fill(
                Path(ellipseIn: nodeRect),
                with: .color(container.status.color.opacity(0.15))
            )
            context.stroke(
                Path(ellipseIn: nodeRect),
                with: .color(container.status.color),
                lineWidth: 2
            )
        }
    }

    @ViewBuilder
    private var topologyOverlay: some View {
        let hostRadius: CGFloat = 48
        let backboneY: CGFloat = 200

        GeometryReader { geo in
            let width = geo.size.width
            let centerX = width / 2

            // Host label
            VStack(spacing: 2) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 22))
                    .foregroundStyle(.blue)
                Text("macOS Host")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                Text("Gateway")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .position(x: centerX, y: 40 + hostRadius)

            // Network label
            Text("vmnet (Shared Network)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .position(x: centerX, y: backboneY - 12)

            // Container labels
            let containerCount = max(runningContainers.count, 1)
            let spacing = (width - 160) / CGFloat(containerCount)
            ForEach(runningContainers.indices, id: \.self) { i in
                let container = runningContainers[i]
                let x = 80 + spacing * CGFloat(i) + spacing / 2
                let y: CGFloat = 330

                VStack(spacing: 2) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(container.status.color)
                    Text(container.displayName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let ip = container.ipAddress {
                        Text(ip)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .position(x: x, y: y)
            }
        }
    }
}

// MARK: - Network Config View

struct NetworkConfigView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                FormSection(title: "Network Mode") {
                    if #available(macOS 26, *) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text("vmnet (Shared Mode)")
                                    .fontWeight(.medium)
                                Text("Each container gets a unique IP on a shared virtual network accessible from the host.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text("Network not available")
                                    .fontWeight(.medium)
                                Text("vmnet networking requires macOS 26 or later.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                FormSection(title: "Default Subnet") {
                    LabeledContent("Subnet CIDR") {
                        TextField("192.168.64.0/24", text: $appState.defaultSubnet)
                            .textFieldStyle(.roundedBorder)
                            .monospaced()
                            .frame(width: 180)
                    }
                    Text("The subnet used for the vmnet network. Containers receive addresses from this range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                FormSection(title: "Host-to-Container Access") {
                    VStack(alignment: .leading, spacing: 10) {
                        NetworkInfoRow(
                            icon: "arrow.right.circle.fill",
                            color: .blue,
                            title: "From macOS host",
                            detail: "Connect directly to the container's IP address on any port. No port mapping needed."
                        )
                        NetworkInfoRow(
                            icon: "arrow.left.circle.fill",
                            color: .green,
                            title: "From container to host",
                            detail: "Use the gateway IP (first address in the subnet, e.g. 192.168.64.1) to reach the macOS host."
                        )
                        NetworkInfoRow(
                            icon: "arrow.left.arrow.right.circle.fill",
                            color: .purple,
                            title: "Inter-container",
                            detail: "Containers on the same vmnet network communicate directly via their IP addresses."
                        )
                    }
                }
            }
            .padding(20)
        }
    }
}

struct NetworkInfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Communication Guide

struct NetworkCommunicationGuide: View {
    @Environment(ContainerService.self) private var containerService

    private var runningContainers: [ContainerRecord] {
        containerService.containers.filter { $0.status == .running && $0.networkEnabled }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Host-to-Container
                FormSection(title: "Host → Container") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Access container services directly from your Mac using the container's IP address.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if runningContainers.isEmpty {
                            Text("No running containers with networking.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            ForEach(runningContainers) { container in
                                if let ip = container.ipAddress {
                                    HStack {
                                        Image(systemName: "shippingbox.fill")
                                            .foregroundStyle(container.status.color)
                                        Text(container.displayName)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("curl http://\(ip):80")
                                            .font(.system(.caption, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(.quinary, in: RoundedRectangle(cornerRadius: 4))
                                        CopyButton(text: "curl http://\(ip):80")
                                    }
                                }
                            }
                        }
                    }
                }

                // Container-to-Host
                FormSection(title: "Container → Host") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("From inside a container, reach the macOS host via the gateway address.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("Gateway IP (example):")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("192.168.64.1")
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quinary, in: RoundedRectangle(cornerRadius: 4))
                            CopyButton(text: "192.168.64.1")
                        }
                        Text("Example: to connect to a database running on your Mac from a container, use host.internal or the gateway IP.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Inter-Container
                FormSection(title: "Container ↔ Container") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Containers on the same vmnet can communicate directly. No extra configuration needed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if runningContainers.count >= 2 {
                            ForEach(runningContainers.indices, id: \.self) { i in
                                ForEach((i+1)..<runningContainers.count, id: \.self) { j in
                                    let a = runningContainers[i]
                                    let b = runningContainers[j]
                                    if let ipA = a.ipAddress, let ipB = b.ipAddress {
                                        HStack {
                                            Text("\(a.displayName)")
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Image(systemName: "arrow.left.arrow.right")
                                                .foregroundStyle(.secondary)
                                            Text("\(b.displayName)")
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(ipA) ↔ \(ipB)")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        } else if runningContainers.count == 1 {
                            Text("Launch another container to see inter-container communication paths.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("No running containers.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // DNS
                FormSection(title: "DNS Resolution") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By default, containers use the gateway as their DNS resolver (usually your Mac's DNS through the virtual network). You can override DNS servers per-container in the Launch dialog.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default DNS").font(.caption).foregroundStyle(.secondary)
                                Text("Gateway IP").font(.system(.caption, design: .monospaced))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Public Fallback").font(.caption).foregroundStyle(.secondary)
                                Text("1.1.1.1 or 8.8.8.8").font(.system(.caption, design: .monospaced))
                            }
                        }
                        .padding(10)
                        .background(.quinary, in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Copy Button helper

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                .foregroundStyle(copied ? .green : .secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
        .help("Copy")
    }
}
