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

@main
struct ContainerManagerApp: App {
    @State private var appState = AppState()
    @State private var containerService = ContainerService()

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environment(appState)
                .environment(containerService)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    // Auto-detect kernel/vmlinux from the repo's kernel/ directory
                    appState.autoDetectKernel()
                    await containerService.initialize(appState: appState)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            AppCommands(appState: appState, containerService: containerService)
        }

        Settings {
            SettingsView()
                .environment(appState)
                .environment(containerService)
        }
    }
}

// MARK: - App Commands

struct AppCommands: Commands {
    var appState: AppState
    var containerService: ContainerService

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Container…") {
                appState.showLaunchSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button("Pull Image…") {
                appState.showPullImageSheet = true
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("Containerization Documentation") {
                NSWorkspace.shared.open(
                    URL(string: "https://github.com/apple/containerization")!
                )
            }
        }
    }
}
