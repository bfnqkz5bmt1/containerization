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

struct ContainerListView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @State private var searchText = ""
    @State private var filterStatus: ContainerStatus? = nil
    @State private var confirmDelete: ContainerRecord? = nil

    private var filteredContainers: [ContainerRecord] {
        containerService.containers.filter { record in
            let matchesSearch = searchText.isEmpty ||
                record.displayName.localizedCaseInsensitiveContains(searchText) ||
                record.imageReference.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterStatus == nil || record.status == filterStatus
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search containers…", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 8))

                StatusFilterMenu(selected: $filterStatus)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if containerService.containers.isEmpty {
                emptyState
            } else if filteredContainers.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredContainers, selection: $appState.selectedContainerID) { record in
                    ContainerRowView(record: record)
                        .tag(record.id)
                        .contextMenu {
                            containerContextMenu(record: record)
                        }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Containers")
        .confirmationDialog(
            "Delete \"\(confirmDelete?.displayName ?? "")\"?",
            isPresented: .init(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let record = confirmDelete {
                    Task {
                        try? await containerService.delete(id: record.id)
                        if appState.selectedContainerID == record.id {
                            appState.selectedContainerID = nil
                        }
                    }
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("This will stop and remove the container and its filesystem. This action cannot be undone.")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "shippingbox")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("No Containers")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Launch your first container to get started.")
                    .foregroundStyle(.secondary)
            }
            Button("Launch Container…") {
                appState.showLaunchSheet = true
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func containerContextMenu(record: ContainerRecord) -> some View {
        if record.status == .running {
            Button {
                Task { try? await containerService.stop(id: record.id) }
            } label: {
                Label("Stop Container", systemImage: "stop.fill")
            }
        } else if record.status == .stopped || record.status == .failed {
            Button {
                appState.selectedContainerID = record.id
                // Re-launch would go here
            } label: {
                Label("Restart Container", systemImage: "arrow.clockwise")
            }
        }

        Divider()

        Button {
            appState.selectedContainerID = record.id
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        Button {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(record.ipAddress ?? "", forType: .string)
        } label: {
            Label("Copy IP Address", systemImage: "doc.on.clipboard")
        }
        .disabled(record.ipAddress == nil)

        Divider()

        Button(role: .destructive) {
            confirmDelete = record
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Status Filter Menu

struct StatusFilterMenu: View {
    @Binding var selected: ContainerStatus?

    var body: some View {
        Menu {
            Button("All") { selected = nil }
            Divider()
            ForEach([ContainerStatus.running, .stopped, .creating, .failed], id: \.rawValue) { status in
                Button {
                    selected = status
                } label: {
                    Label(status.rawValue, systemImage: status.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                if let s = selected {
                    Text(s.rawValue)
                        .font(.caption)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Container Row View

struct ContainerRowView: View {
    var record: ContainerRecord

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(record.status.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(record.status.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(record.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    StatusBadge(status: record.status)
                }

                Text(record.imageReference)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let ip = record.ipAddress {
                        Label(ip, systemImage: "network")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Label("\(record.cpus) CPU", systemImage: "cpu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Label(record.memoryFormatted, systemImage: "memorychip")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// Note: ContainerRecord uses @Observable (Observation framework / Swift 5.9+).
// ContainerRowView reads it directly which causes SwiftUI to track dependencies.

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ContainerStatus

    var body: some View {
        HStack(spacing: 4) {
            if status == .running {
                Circle()
                    .fill(status.color)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(status.color.opacity(0.3), lineWidth: 2)
                            .scaleEffect(1.8)
                            .opacity(0.6)
                    )
            } else {
                Image(systemName: status.icon)
                    .font(.system(size: 8))
                    .foregroundStyle(status.color)
            }
            Text(status.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(status.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(status.color.opacity(0.1), in: Capsule())
    }
}
