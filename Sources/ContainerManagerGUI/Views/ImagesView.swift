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

struct ImagesView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @State private var searchText = ""
    @State private var confirmDelete: ImageRecord? = nil

    private var filteredImages: [ImageRecord] {
        guard !searchText.isEmpty else { return containerService.images }
        return containerService.images.filter {
            $0.reference.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            // Search bar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search images…", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.quinary, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    Task { await containerService.refreshImages() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh images")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Pull progress banners
            if !containerService.pullProgresses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(containerService.pullProgresses) { progress in
                        PullProgressBanner(progress: progress)
                    }
                }
            }

            if containerService.images.isEmpty {
                emptyState
            } else if filteredImages.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredImages, selection: $appState.selectedImageID) { image in
                    ImageRowView(image: image)
                        .tag(image.id)
                        .contextMenu {
                            Button {
                                // Launch with this image
                                appState.showLaunchSheet = true
                            } label: {
                                Label("Launch Container…", systemImage: "play.fill")
                            }
                            Divider()
                            Button(role: .destructive) {
                                confirmDelete = image
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(image.isBuiltin)
                        }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("Images")
        .confirmationDialog(
            "Delete \"\(confirmDelete?.displayName ?? "")\"?",
            isPresented: .init(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let img = confirmDelete {
                    Task { try? await containerService.deleteImage(id: img.id) }
                }
                confirmDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("This will permanently remove the image and its layers from the local store.")
        }
        .task { await containerService.refreshImages() }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.stack.3d.up")
                .resizable().scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(.tertiary)
            VStack(spacing: 8) {
                Text("No Images")
                    .font(.title2).fontWeight(.semibold)
                Text("Pull an OCI image to get started.")
                    .foregroundStyle(.secondary)
            }
            Button("Pull Image…") { appState.showPullImageSheet = true }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Image Row

struct ImageRowView: View {
    var image: ImageRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(image.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    if image.isBuiltin {
                        Text("built-in")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 12) {
                    Label(image.platform, systemImage: "cpu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if image.sizeBytes > 0 {
                        Label(image.sizeFormatted, systemImage: "externaldrive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(image.shortDigest)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Image Detail View

struct ImageDetailView: View {
    var record: ImageRecord
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                InfoSection(title: "Image") {
                    InfoRow(label: "Reference", value: record.reference, monospace: true)
                    InfoRow(label: "Digest", value: record.id, monospace: true)
                    InfoRow(label: "Platform", value: record.platform)
                    if record.sizeBytes > 0 {
                        InfoRow(label: "Size", value: record.sizeFormatted)
                    }
                    if let created = record.createdAt {
                        InfoRow(label: "Created", value: created.formatted(date: .abbreviated, time: .shortened))
                    }
                    InfoRow(label: "Built-in", value: record.isBuiltin ? "Yes" : "No")
                }

                HStack {
                    Button("Launch Container…") {
                        appState.showLaunchSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .navigationTitle(record.displayName)
    }
}

// MARK: - Pull Image View (Sheet)

struct PullImageView: View {
    @Environment(AppState.self) private var appState
    @Environment(ContainerService.self) private var containerService
    @Environment(\.dismiss) private var dismiss

    @State private var imageReference = ""
    @State private var isPulling = false
    @State private var errorMessage: String?

    private let suggestions = [
        "docker.io/library/alpine:latest",
        "docker.io/library/ubuntu:22.04",
        "docker.io/library/debian:bookworm-slim",
        "docker.io/library/nginx:alpine",
        "docker.io/library/redis:alpine",
        "docker.io/library/python:3.12-slim",
        "docker.io/library/node:20-alpine",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.accentColor)
                VStack(alignment: .leading) {
                    Text("Pull Image")
                        .font(.title3).fontWeight(.semibold)
                    Text("Download an OCI container image")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Pull") { pullImage() }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageReference.isEmpty || isPulling)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
            .background(.regularMaterial)

            Divider()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image Reference")
                        .font(.headline)
                    TextField("docker.io/library/alpine:latest", text: $imageReference)
                        .textFieldStyle(.roundedBorder)
                        .monospaced()
                        .onSubmit { pullImage() }
                    Text("Enter a fully-qualified OCI image reference (registry/repository:tag or @sha256:digest)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions")
                        .font(.headline)
                    FlowLayout(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                imageReference = suggestion
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                            .monospaced()
                        }
                    }
                }

                if let err = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if isPulling {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView("Pulling \(imageReference)…")
                        Text("This may take a moment for large images.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)

            Spacer()
        }
        .frame(width: 500, height: 420)
    }

    private func pullImage() {
        guard !imageReference.isEmpty else { return }
        isPulling = true
        errorMessage = nil
        let ref = imageReference

        Task {
            do {
                try await containerService.pullImage(reference: ref)
                await MainActor.run {
                    isPulling = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPulling = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Pull Progress Banner

struct PullProgressBanner: View {
    var progress: PullProgress

    var body: some View {
        HStack(spacing: 10) {
            switch progress.status {
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            default:
                ProgressView().scaleEffect(0.6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.reference)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(progress.message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if progress.status == .downloading || progress.status == .extracting {
                ProgressView(value: progress.progressFraction)
                    .frame(width: 80)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.05))
    }
}


// MARK: - Flow Layout (simple wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 400
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width + (rowWidth > 0 ? spacing : 0) > maxWidth {
                height += rowHeight + spacing
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
