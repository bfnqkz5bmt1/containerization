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

// MARK: - Network Record

@Observable
final class NetworkRecord: Identifiable {
    let id = UUID()
    var name: String
    var subnet: String
    var gateway: String
    var networkMode: NetworkMode
    var isActive: Bool
    var connectedContainerIDs: [String]

    enum NetworkMode: String, CaseIterable {
        case vmnet = "vmnet (macOS 26+)"
        case nat = "NAT"
        case none = "None"

        var icon: String {
            switch self {
            case .vmnet: return "network.badge.shield.half.filled"
            case .nat: return "arrow.triangle.2.circlepath"
            case .none: return "slash.circle"
            }
        }
    }

    init(
        name: String = "default",
        subnet: String = "192.168.64.0/24",
        gateway: String = "192.168.64.1",
        networkMode: NetworkMode = .vmnet,
        isActive: Bool = false,
        connectedContainerIDs: [String] = []
    ) {
        self.name = name
        self.subnet = subnet
        self.gateway = gateway
        self.networkMode = networkMode
        self.isActive = isActive
        self.connectedContainerIDs = connectedContainerIDs
    }
}

// MARK: - Port Mapping

struct PortMapping: Identifiable, Hashable {
    let id = UUID()
    var hostPort: Int
    var containerPort: Int
    var containerID: String
    var protocol_: String = "tcp"

    var displayName: String {
        "localhost:\(hostPort) → \(containerID):\(containerPort)/\(protocol_)"
    }
}
