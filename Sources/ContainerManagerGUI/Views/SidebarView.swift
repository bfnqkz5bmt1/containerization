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

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedSidebarItem) {
            Section("Management") {
                SidebarItemView(item: .containers, badge: runningCount)
                SidebarItemView(item: .images, badge: nil)
                SidebarItemView(item: .network, badge: nil)
            }

            Section("App") {
                SidebarItemView(item: .settings, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Containers")
        .frame(minWidth: 180)
    }

    private var runningCount: Int? {
        let count = containerService.containers.filter { $0.status == .running }.count
        return count > 0 ? count : nil
    }
}

// MARK: - Sidebar Item View

struct SidebarItemView: View {
    let item: SidebarItem
    let badge: Int?

    var body: some View {
        Label(item.label, systemImage: item.icon)
            .badge(badge ?? 0)
    }
}
