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

import Foundation
import SwiftUI

// MARK: - Sidebar Selection

enum SidebarItem: Hashable, Identifiable {
    case containers
    case images
    case network
    case settings

    var id: Self { self }

    var label: String {
        switch self {
        case .containers: return "Containers"
        case .images: return "Images"
        case .network: return "Network"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .containers: return "shippingbox.fill"
        case .images: return "square.stack.3d.up.fill"
        case .network: return "network"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - App State

@Observable
@MainActor
final class AppState {
    // Navigation
    var selectedSidebarItem: SidebarItem = .containers
    var selectedContainerID: String?
    var selectedImageID: String?

    // Sheets
    var showLaunchSheet = false
    var showPullImageSheet = false
    var showSettingsSheet = false
    var showNetworkConfigSheet = false

    // Alerts
    var alertTitle = ""
    var alertMessage = ""
    var showAlert = false

    // Settings (persisted via UserDefaults)
    var kernelPath: String {
        get { UserDefaults.standard.string(forKey: "kernelPath") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "kernelPath") }
    }

    var initfsReference: String {
        get { UserDefaults.standard.string(forKey: "initfsReference") ?? "vminit:latest" }
        set { UserDefaults.standard.set(newValue, forKey: "initfsReference") }
    }

    var defaultSubnet: String {
        get { UserDefaults.standard.string(forKey: "defaultSubnet") ?? "192.168.64.0/24" }
        set { UserDefaults.standard.set(newValue, forKey: "defaultSubnet") }
    }

    var defaultCPUs: Int {
        get { UserDefaults.standard.integer(forKey: "defaultCPUs") == 0 ? 2 : UserDefaults.standard.integer(forKey: "defaultCPUs") }
        set { UserDefaults.standard.set(newValue, forKey: "defaultCPUs") }
    }

    var defaultMemoryMB: UInt64 {
        get {
            let v = UserDefaults.standard.integer(forKey: "defaultMemoryMB")
            return v == 0 ? 1024 : UInt64(v)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "defaultMemoryMB") }
    }

    var isKernelConfigured: Bool {
        !kernelPath.isEmpty && FileManager.default.fileExists(atPath: kernelPath)
    }

    // MARK: - Kernel Auto-Detection

    /// Searches well-known locations for the project's built kernel (kernel/vmlinux).
    /// Called on first launch if no kernel is configured yet.
    func autoDetectKernel() {
        guard kernelPath.isEmpty || !FileManager.default.fileExists(atPath: kernelPath) else {
            return // already have a valid kernel configured
        }

        if let found = findKernel() {
            kernelPath = found
        }
    }

    /// Returns the path to `kernel/vmlinux` if found in any of the search locations.
    ///
    /// Search order:
    /// 1. Alongside the running executable (dev build: .build/arm64-apple-macosx/debug/)
    /// 2. Two directories up from the executable, then `kernel/vmlinux`
    ///    (covers `.build/<arch>/debug/ContainerManagerGUI` → repo root → `kernel/vmlinux`)
    /// 3. Application Support: `~/Library/Application Support/com.apple.containerization/vmlinux`
    /// 4. User's home directory `~/vmlinux`
    private func findKernel() -> String? {
        var candidates: [URL] = []

        // 1. Resolve the repo root from the executable path.
        //    Typical SPM build: <repo>/.build/<arch>/<config>/ContainerManagerGUI
        //    Walk up until we find the `kernel/` directory.
        let execURL = URL(fileURLWithPath: CommandLine.arguments[0])
            .standardized.resolvingSymlinksInPath()

        var dir = execURL.deletingLastPathComponent()
        for _ in 0..<6 {
            let kernelVmlinux = dir.appendingPathComponent("kernel/vmlinux")
            candidates.append(kernelVmlinux)
            dir = dir.deletingLastPathComponent()
        }

        // 2. Application Support directory (matches cctl's appRoot convention)
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            candidates.append(
                appSupport.appendingPathComponent("com.apple.containerization/vmlinux")
            )
        }

        // 3. Home directory fallback
        candidates.append(
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("vmlinux")
        )

        return candidates
            .map { $0.path }
            .first { FileManager.default.fileExists(atPath: $0) }
    }

    func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
