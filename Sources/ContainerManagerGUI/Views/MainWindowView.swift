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

struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            contentView
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appState.showLaunchSheet) {
            LaunchContainerView()
                .environment(appState)
                .environment(containerService)
        }
        .sheet(isPresented: $appState.showPullImageSheet) {
            PullImageView()
                .environment(appState)
                .environment(containerService)
        }
        .alert(appState.alertTitle, isPresented: $appState.showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.alertMessage)
        }
        .toolbar {
            toolbarItems
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedSidebarItem {
        case .containers:
            ContainerListView()
                .environment(appState)
                .environment(containerService)
        case .images:
            ImagesView()
                .environment(appState)
                .environment(containerService)
        case .network:
            NetworkView()
                .environment(appState)
                .environment(containerService)
        case .settings:
            SettingsView()
                .environment(appState)
                .environment(containerService)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        @Bindable var appState = appState

        if appState.selectedSidebarItem == .containers,
           let id = appState.selectedContainerID,
           let record = containerService.containers.first(where: { $0.id == id }) {
            ContainerDetailView(record: record)
                .environment(appState)
                .environment(containerService)
        } else if appState.selectedSidebarItem == .images,
                  let id = appState.selectedImageID,
                  let record = containerService.images.first(where: { $0.id == id }) {
            ImageDetailView(record: record)
                .environment(appState)
                .environment(containerService)
        } else {
            EmptyDetailView(sidebarItem: appState.selectedSidebarItem)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if appState.selectedSidebarItem == .containers {
                Button {
                    appState.showLaunchSheet = true
                } label: {
                    Label("New Container", systemImage: "plus.circle.fill")
                }
                .help("Launch a new container (⌘N)")
            }

            if appState.selectedSidebarItem == .images {
                Button {
                    appState.showPullImageSheet = true
                } label: {
                    Label("Pull Image", systemImage: "arrow.down.circle.fill")
                }
                .help("Pull a container image (⇧⌘P)")
            }
        }

        ToolbarItemGroup(placement: .status) {
            if containerService.isInitializing {
                ProgressView()
                    .scaleEffect(0.6)
                    .help("Initializing…")
            } else if let err = containerService.initError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .help(err)
            } else if containerService.isInitialized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .help("Container runtime ready")
            }
        }
    }
}

// MARK: - Empty Detail View

struct EmptyDetailView: View {
    let sidebarItem: SidebarItem

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(.tertiary)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: String {
        switch sidebarItem {
        case .containers: return "shippingbox"
        case .images: return "square.stack.3d.up"
        case .network: return "network"
        case .settings: return "gearshape"
        }
    }

    private var message: String {
        switch sidebarItem {
        case .containers: return "Select a container to view details"
        case .images: return "Select an image to view details"
        case .network: return "Network configuration"
        case .settings: return "Application settings"
        }
    }
}
