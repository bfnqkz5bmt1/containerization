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
import Containerization

// MARK: - Container Status

enum ContainerStatus: String, Equatable {
    case creating = "Creating"
    case running = "Running"
    case stopped = "Stopped"
    case stopping = "Stopping"
    case failed = "Failed"

    var color: Color {
        switch self {
        case .creating: return .yellow
        case .running: return .green
        case .stopped: return .secondary
        case .stopping: return .orange
        case .failed: return .red
        }
    }

    var icon: String {
        switch self {
        case .creating: return "clock.arrow.2.circlepath"
        case .running: return "circle.fill"
        case .stopped: return "stop.circle"
        case .stopping: return "arrow.clockwise.circle"
        case .failed: return "exclamationmark.circle"
        }
    }
}

// MARK: - Container Record

@Observable
final class ContainerRecord: Identifiable {
    let id: String
    var name: String
    var imageReference: String
    var status: ContainerStatus
    var ipAddress: String?
    var macAddress: String?
    var networkSubnet: String?
    var cpus: Int
    var memoryMB: UInt64
    var fsSizeMB: UInt64
    var createdAt: Date
    var logs: String
    var errorMessage: String?
    var networkEnabled: Bool
    var rosettaEnabled: Bool
    var mounts: [MountRecord]
    var environmentVariables: [String]
    var command: [String]
    var workingDirectory: String
    var capabilityPreset: CapabilityPreset
    var customCapabilities: [String]
    var useInit: Bool
    var readOnly: Bool

    // Held reference to the running container (not persisted)
    var container: LinuxContainer?

    init(
        id: String,
        name: String,
        imageReference: String,
        cpus: Int = 2,
        memoryMB: UInt64 = 1024,
        fsSizeMB: UInt64 = 4096,
        networkEnabled: Bool = true,
        rosettaEnabled: Bool = false,
        mounts: [MountRecord] = [],
        environmentVariables: [String] = [],
        command: [String] = [],
        workingDirectory: String = "/",
        capabilityPreset: CapabilityPreset = .default,
        customCapabilities: [String] = [],
        useInit: Bool = false,
        readOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.imageReference = imageReference
        self.status = .stopped
        self.cpus = cpus
        self.memoryMB = memoryMB
        self.fsSizeMB = fsSizeMB
        self.networkEnabled = networkEnabled
        self.rosettaEnabled = rosettaEnabled
        self.mounts = mounts
        self.environmentVariables = environmentVariables
        self.command = command
        self.workingDirectory = workingDirectory
        self.capabilityPreset = capabilityPreset
        self.customCapabilities = customCapabilities
        self.useInit = useInit
        self.readOnly = readOnly
        self.createdAt = Date()
        self.logs = ""
    }

    var displayName: String {
        name.isEmpty ? id : name
    }

    var memoryFormatted: String {
        if memoryMB >= 1024 {
            String(format: "%.1f GB", Double(memoryMB) / 1024.0)
        } else {
            "\(memoryMB) MB"
        }
    }

    var fsSizeFormatted: String {
        if fsSizeMB >= 1024 {
            String(format: "%.1f GB", Double(fsSizeMB) / 1024.0)
        } else {
            "\(fsSizeMB) MB"
        }
    }
}

// MARK: - Mount Record

struct MountRecord: Identifiable, Hashable {
    let id = UUID()
    var hostPath: String
    var containerPath: String
    var readOnly: Bool = false
}

// MARK: - Capability Preset

enum CapabilityPreset: String, CaseIterable, Identifiable {
    case restricted = "Restricted"
    case `default` = "Default (OCI)"
    case full = "Full (All Caps)"
    case custom = "Custom"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .restricted: return "Minimal capabilities for security"
        case .default: return "Standard OCI default capabilities"
        case .full: return "All Linux capabilities (privileged)"
        case .custom: return "Manually specify capabilities"
        }
    }

    var icon: String {
        switch self {
        case .restricted: return "lock.shield"
        case .default: return "shield"
        case .full: return "shield.slash"
        case .custom: return "slider.horizontal.3"
        }
    }
}
