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
import ContainerizationOCI
import ContainerizationOS
import Logging

// MARK: - Launch Configuration

struct LaunchConfig {
    var id: String
    var name: String
    var imageReference: String
    var cpus: Int
    var memoryMB: UInt64
    var fsSizeMB: UInt64
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
    var nameservers: [String]

    init(defaults: AppState) {
        self.id = UUID().uuidString.lowercased().prefix(8).description
        self.name = ""
        self.imageReference = "docker.io/library/alpine:latest"
        self.cpus = defaults.defaultCPUs
        self.memoryMB = defaults.defaultMemoryMB
        self.fsSizeMB = 4096
        self.networkEnabled = true
        self.rosettaEnabled = false
        self.mounts = []
        self.environmentVariables = []
        self.command = []
        self.workingDirectory = "/"
        self.capabilityPreset = .default
        self.customCapabilities = []
        self.useInit = false
        self.readOnly = false
        self.nameservers = []
    }
}

// MARK: - Output Capture Writer

/// Captures container process output into a string buffer.
final class OutputCaptureWriter: Writer, @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: Data = Data()

    func write(_ data: Data) throws {
        lock.withLock { buffer.append(data) }
    }

    func close() throws {}

    var output: String {
        lock.withLock {
            String(data: buffer, encoding: .utf8) ?? ""
        }
    }
}

// MARK: - Container Service

@Observable
@MainActor
final class ContainerService {
    var containers: [ContainerRecord] = []
    var images: [ImageRecord] = []
    var pullProgresses: [PullProgress] = []
    var isInitialized = false
    var isInitializing = false
    var initError: String?

    // Internal mutable state — must be mutated carefully since ContainerManager is a struct
    private var manager: ContainerManager?
    private var logger = Logger(label: "com.apple.containerization.gui")

    // MARK: - Initialization

    func initialize(appState: AppState) async {
        guard !isInitializing else { return }
        isInitializing = true
        defer { isInitializing = false }

        guard appState.isKernelConfigured else {
            initError = "Kernel not configured. Please set the kernel path in Settings."
            return
        }

        do {
            let kernelURL = URL(fileURLWithPath: appState.kernelPath)
            let kernel = Kernel(path: kernelURL, platform: .linuxArm)

            // Select network based on macOS version
            let network: ContainerManager.Network?
            if #available(macOS 26, *) {
                network = try ContainerManager.VmnetNetwork()
            } else {
                network = nil
            }

            self.manager = try await ContainerManager(
                kernel: kernel,
                initfsReference: appState.initfsReference,
                network: network,
                rosetta: false
            )

            isInitialized = true
            initError = nil

            await refreshImages()
        } catch {
            initError = error.localizedDescription
            logger.error("Failed to initialize ContainerService: \(error)")
        }
    }

    // MARK: - Container Launch

    func launch(config: LaunchConfig) async throws {
        guard manager != nil else {
            throw ContainerServiceError.notInitialized
        }

        let record = ContainerRecord(
            id: config.id,
            name: config.name.isEmpty ? config.id : config.name,
            imageReference: config.imageReference,
            cpus: config.cpus,
            memoryMB: config.memoryMB,
            fsSizeMB: config.fsSizeMB,
            networkEnabled: config.networkEnabled,
            rosettaEnabled: config.rosettaEnabled,
            mounts: config.mounts,
            environmentVariables: config.environmentVariables,
            command: config.command,
            workingDirectory: config.workingDirectory,
            capabilityPreset: config.capabilityPreset,
            customCapabilities: config.customCapabilities,
            useInit: config.useInit,
            readOnly: config.readOnly
        )
        record.status = .creating
        containers.append(record)

        do {
            let container = try await createContainer(config: config, record: record)
            record.container = container
            record.status = .running

            // Start the container lifecycle — Task inherits @MainActor from ContainerService
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await container.create()
                    try await container.start()
                    self.appendLogSync(to: record, message: "Container started.")
                    try await container.wait()
                    record.status = .stopped
                    self.appendLogSync(to: record, message: "Container exited.")
                } catch {
                    record.status = .failed
                    record.errorMessage = error.localizedDescription
                    self.appendLogSync(to: record, message: "Error: \(error.localizedDescription)")
                    self.logger.error("Container \(record.id) failed: \(error)")
                }
            }
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            throw error
        }
    }

    private func createContainer(config: LaunchConfig, record: ContainerRecord) async throws -> LinuxContainer {
        guard var mgr = self.manager else {
            throw ContainerServiceError.notInitialized
        }

        // Use local box to capture network interface info from inside the closure
        var capturedIPAddress: String? = nil
        var capturedSubnet: String? = nil
        var capturedMAC: String? = nil

        let container = try await mgr.create(
            config.id,
            reference: config.imageReference,
            rootfsSizeInBytes: config.fsSizeMB * 1024 * 1024,
            readOnly: config.readOnly,
            networking: config.networkEnabled
        ) { cfg in
            cfg.cpus = config.cpus
            cfg.memoryInBytes = config.memoryMB * 1024 * 1024
            cfg.process.workingDirectory = config.workingDirectory

            // Apply capability preset
            switch config.capabilityPreset {
            case .restricted:
                cfg.process.capabilities = LinuxCapabilities(capabilities: [
                    .netBindService, .setuid, .setgid, .kill
                ])
            case .default:
                cfg.process.capabilities = .defaultOCICapabilities
            case .full:
                cfg.process.capabilities = .allCapabilities
            case .custom:
                let caps = config.customCapabilities.compactMap { name in
                    CapabilityName.allCases.first {
                        $0.description.lowercased() == name.lowercased()
                    }
                }
                cfg.process.capabilities = LinuxCapabilities(capabilities: caps)
            }

            // Append custom environment variables
            cfg.process.environmentVariables.append(contentsOf: config.environmentVariables)

            // Override command if provided
            if !config.command.isEmpty {
                cfg.process.arguments = config.command
            }

            // Add virtiofs directory shares
            for mount in config.mounts {
                cfg.mounts.append(
                    Mount.share(
                        source: mount.hostPath,
                        destination: mount.containerPath
                    )
                )
            }

            // Configure custom DNS nameservers (macOS 26+ only)
            if !config.nameservers.isEmpty {
                if #available(macOS 26, *) {
                    cfg.dns = DNS(nameservers: config.nameservers)
                }
            }

            cfg.useInit = config.useInit

            // Capture network interface info for display
            if let iface = cfg.interfaces.first {
                capturedIPAddress = iface.ipv4Address.address.description
                capturedSubnet = iface.ipv4Address.description
                capturedMAC = iface.macAddress?.description
            }
        }

        // Save updated manager (mutated by create) and apply network info
        self.manager = mgr
        record.ipAddress = capturedIPAddress
        record.networkSubnet = capturedSubnet
        record.macAddress = capturedMAC
        return container
    }

    // MARK: - Container Control

    func stop(id: String) async throws {
        guard let record = containers.first(where: { $0.id == id }),
              let container = record.container else { return }

        record.status = .stopping
        do {
            try await container.stop()
            record.status = .stopped
        } catch {
            record.status = .failed
            record.errorMessage = error.localizedDescription
            throw error
        }
    }

    func delete(id: String) async throws {
        guard let idx = containers.firstIndex(where: { $0.id == id }) else { return }
        let record = containers[idx]

        // Stop first if running
        if record.status == .running, let container = record.container {
            try? await container.stop()
        }

        // Clean up manager resources (network, filesystem)
        if var mgr = self.manager {
            try? mgr.delete(id)
            self.manager = mgr
        }

        containers.remove(at: idx)
    }

    // MARK: - Exec in Container

    func execInContainer(id: String, command: [String]) async throws -> String {
        guard let record = containers.first(where: { $0.id == id }),
              let container = record.container else {
            throw ContainerServiceError.containerNotRunning
        }

        let stdoutWriter = OutputCaptureWriter()
        let stderrWriter = OutputCaptureWriter()

        let process = try await container.exec("exec-\(UUID().uuidString.prefix(6))") { cfg in
            cfg.arguments = command
            cfg.workingDirectory = record.workingDirectory
            cfg.capabilities = .defaultOCICapabilities
            cfg.stdout = stdoutWriter
            cfg.stderr = stderrWriter
        }

        let _ = try await process.wait()

        let out = stdoutWriter.output
        let err = stderrWriter.output
        return out + (err.isEmpty ? "" : "\n[stderr]\n\(err)")
    }

    // MARK: - Image Management

    func pullImage(reference: String) async throws {
        guard manager != nil else {
            throw ContainerServiceError.notInitialized
        }

        let progress = PullProgress(reference: reference)
        pullProgresses.append(progress)

        do {
            progress.status = .downloading
            progress.message = "Pulling \(reference)…"
            progress.progressFraction = 0.1

            // Use imageStore.get with pull:true which pulls if not found
            let _ = try await manager!.imageStore.get(reference: reference, pull: true)

            progress.progressFraction = 0.9
            progress.status = .extracting
            progress.message = "Processing layers…"

            progress.progressFraction = 1.0
            progress.status = .done
            progress.message = "Done"

            await refreshImages()
        } catch {
            progress.status = .failed
            progress.message = "Failed: \(error.localizedDescription)"
            throw error
        }

        // Auto-dismiss progress after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                self.pullProgresses.removeAll { $0.id == progress.id && $0.status == .done }
            }
        }
    }

    func deleteImage(id: String) async throws {
        guard let manager = self.manager else {
            throw ContainerServiceError.notInitialized
        }
        guard let record = images.first(where: { $0.id == id }) else { return }
        try await manager.imageStore.delete(reference: record.reference)
        images.removeAll { $0.id == id }
    }

    func refreshImages() async {
        guard let manager = self.manager else { return }

        do {
            let stored = try await manager.imageStore.list()
            images = stored.map { img in
                ImageRecord(
                    id: img.digest,
                    reference: img.reference,
                    tag: extractTag(from: img.reference),
                    repository: extractRepo(from: img.reference),
                    platform: "linux/arm64",
                    sizeBytes: 0,
                    createdAt: nil,
                    isBuiltin: img.reference.contains("vminit")
                )
            }
        } catch {
            logger.error("Failed to list images: \(error)")
        }
    }

    // MARK: - Helpers

    private func appendLogSync(to record: ContainerRecord, message: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        record.logs += "[\(ts)] \(message)\n"
    }

    private func extractTag(from reference: String) -> String {
        // e.g. docker.io/library/alpine:3.16 → "3.16"
        let parts = reference.split(separator: ":")
        if parts.count >= 2 {
            let lastPart = String(parts.last!)
            if !lastPart.contains("/") { return lastPart }
        }
        return "latest"
    }

    private func extractRepo(from reference: String) -> String {
        let parts = reference.split(separator: "/")
        if let last = parts.last {
            let s = String(last)
            if let colon = s.lastIndex(of: ":") {
                return String(s[s.startIndex..<colon])
            }
            return s
        }
        return reference
    }
}

// MARK: - Errors

enum ContainerServiceError: LocalizedError {
    case notInitialized
    case containerNotRunning
    case kernelNotFound

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Container runtime not initialized. Please configure the kernel path in Settings."
        case .containerNotRunning:
            return "Container is not running."
        case .kernelNotFound:
            return "Kernel binary not found at the specified path."
        }
    }
}
