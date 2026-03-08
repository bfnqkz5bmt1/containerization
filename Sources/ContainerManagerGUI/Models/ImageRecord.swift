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

// MARK: - Image Record

@Observable
final class ImageRecord: Identifiable {
    let id: String          // digest
    var reference: String   // e.g. "docker.io/library/alpine:3.16"
    var tag: String
    var repository: String
    var platform: String
    var sizeBytes: Int64
    var createdAt: Date?
    var isBuiltin: Bool     // e.g. vminit:latest

    init(
        id: String,
        reference: String,
        tag: String = "",
        repository: String = "",
        platform: String = "linux/arm64",
        sizeBytes: Int64 = 0,
        createdAt: Date? = nil,
        isBuiltin: Bool = false
    ) {
        self.id = id
        self.reference = reference
        self.tag = tag
        self.repository = repository
        self.platform = platform
        self.sizeBytes = sizeBytes
        self.createdAt = createdAt
        self.isBuiltin = isBuiltin
    }

    var sizeFormatted: String {
        let mb = Double(sizeBytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    var shortDigest: String {
        let hash = id.replacingOccurrences(of: "sha256:", with: "")
        return String(hash.prefix(12))
    }

    var displayName: String {
        reference.isEmpty ? id : reference
    }

    var registryHost: String {
        let parts = reference.split(separator: "/")
        if parts.count >= 2 && (parts[0].contains(".") || parts[0].contains(":")) {
            return String(parts[0])
        }
        return "docker.io"
    }
}

// MARK: - Pull Progress

@Observable
final class PullProgress: Identifiable {
    let id = UUID()
    var reference: String
    var status: PullStatus
    var message: String
    var progressFraction: Double

    enum PullStatus {
        case queued, downloading, extracting, done, failed
    }

    init(reference: String) {
        self.reference = reference
        self.status = .queued
        self.message = "Queued"
        self.progressFraction = 0
    }
}
