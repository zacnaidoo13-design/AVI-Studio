import SwiftUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers
import PhotosUI
import CoreTransferable

// MARK: - Imported Camera Roll Video

struct ImportedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty
                ? "mov"
                : received.file.pathExtension

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)

            try FileManager.default.copyItem(
                at: received.file,
                to: destination
            )

            return ImportedMovie(url: destination)
        }
    }
}

// MARK: - Clip Model

struct EditorClip: Identifiable {
    var id = UUID()
    let url: URL
    let name: String
    let sourceDuration: Double
    var sourceStart: Double
    var sourceEnd: Double

    var duration: Double {
        max(0, sourceEnd - sourceStart)
    }
}

// MARK: - Main Editor

struct ContentView: View {

    @State private var clips: [EditorClip] = []
    @State private var selectedClipID: UUID?
    @State private var player: AVPlayer?

    @State private var showingImporter = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    @State private var isExporting = false
    @State private var exportedURL: URL?

    @State private var alertMessage = ""
    @State private var showingAlert = false

    // MARK: - Design

    private let silver = Color(
        red: 0.78,
        green: 0.81,
        blue: 0.86
    )

    private let background = Color(
        red: 0.025,
        green: 0.03,
        blue: 0.04
    )

    private let panel = Color(
        red: 0.075,
        green: 0.085,
        blue: 0.10
    )

    private let secondaryPanel = Color(
        red: 0.11,
        green: 0.12,
        blue: 0.14
    )

    // MARK: - Computed Properties

    private var selectedIndex: Int? {
        clips.firstIndex { $0.id == selectedClipID }
    }

    private var selectedClip: EditorClip? {
        guard let index = selectedIndex else {
            return nil
        }

        return clips[index]
    }

    private var totalDuration: Double {
        clips.reduce(0) {
            $0 + $1.duration
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header

                        preview

                        importButton

                        timeline

                        editingControls

                        exportButton

                        footer
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 35)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .top
                )
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AVI STUDIO")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(silver)
                }
            }
            .toolbarBackground(background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            // Files importer
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [
                    .movie,
                    .mpeg4Movie,
                    .quickTimeMovie
                ],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    Task {
                        await importVideos(urls)
                    }

                case .failure(let error):
                    showError(error.localizedDescription)
                }
            }

            // Camera Roll importer
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else {
                    return
                }

                Task {
                    await importFromPhotos(items)
                    selectedPhotoItems = []
                }
            }

            .alert(
                "AVI STUDIO",
                isPresented: $showingAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
        .tint(silver)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("THE CREATIVE STUDIO")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(silver.opacity(0.75))

            Text("Create without\nlimits.")
                .font(.system(size: 37, weight: .semibold))
                .tracking(-1.5)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("Your ideas. Your creation.")
                    .foregroundStyle(.gray)

                Spacer()

                Text(timeString(totalDuration))
                    .foregroundStyle(silver)
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Preview

    private var preview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PREVIEW")
                    .tracking(2)

                Spacer()

                Circle()
                    .fill(silver)
                    .frame(width: 6, height: 6)

                Text("AVI STUDIO")
                    .foregroundStyle(silver)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(14)

            ZStack {
                Color.black

                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 13) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 38, weight: .light))
                            .foregroundStyle(silver)

                        Text("Your canvas awaits")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)

                        Text("Import a video to begin editing.")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipped()

            HStack {
                Button {
                    player?.seek(
                        to: .zero,
                        toleranceBefore: .zero,
                        toleranceAfter: .zero
                    )
                } label: {
                    Image(systemName: "backward.end.fill")
                }

                Spacer()

                Button {
                    if player?.timeControlStatus == .playing {
                        player?.pause()
                    } else {
                        player?.play()
                    }
                } label: {
                    Image(systemName: "play.pause.fill")
                        .font(.system(size: 19))
                }

                Spacer()

                Button {
                    if let clip = selectedClip {
                        player?.seek(
                            to: CMTime(
                                seconds: clip.sourceStart,
                                preferredTimescale: 600
                            )
                        )
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .foregroundStyle(silver)
            .padding(16)
        }
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - Import Buttons

    private var importButton: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD YOUR MEDIA")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(.gray)

            HStack(spacing: 10) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 20,
                    matching: .videos,
                    photoLibrary: .shared()
                ) {
                    Label(
                        "Camera Roll",
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(silver)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }

                Button {
                    showingImporter = true
                } label: {
                    Label(
                        "Files",
                        systemImage: "folder"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(silver)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(secondaryPanel)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("TIMELINE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)

                Spacer()

                Text("\(clips.count) CLIPS")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
            }

            if clips.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 25))
                        .foregroundStyle(silver.opacity(0.7))

                    Text("Your timeline is empty")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)

                    Text("Import media to start your project.")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(secondaryPanel.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 11))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 9) {
                        ForEach(clips) { clip in
                            Button {
                                selectClip(clip)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(systemName: "film")
                                        .font(.system(size: 20))
                                        .foregroundStyle(silver)

                                    Text(clip.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                        .foregroundStyle(.white)

                                    Text(timeString(clip.duration))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.gray)
                                }
                                .padding(11)
                                .frame(
                                    width: 120,
                                    height: 88,
                                    alignment: .leading
                                )
                                .background(
                                    selectedClipID == clip.id
                                    ? silver.opacity(0.15)
                                    : secondaryPanel
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            selectedClipID == clip.id
                                            ? silver
                                            : Color.white.opacity(0.04),
                                            lineWidth: 1
                                        )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Divider()
                .overlay(Color.white.opacity(0.08))

            HStack {
                Label("VIDEO TRACK", systemImage: "film")
                Spacer()
                Text(timeString(totalDuration))
                    .monospacedDigit()
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(silver)
        }
        .padding(15)
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - Editing Controls

    private var editingControls: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("EDITING TOOLS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)

            if let clip = selectedClip {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Image(systemName: "film")
                            .foregroundStyle(silver)

                        Text(clip.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("TRIM START")
                            Spacer()
                            Text(timeString(clip.sourceStart))
                                .monospacedDigit()
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)

                        Slider(
                            value: Binding(
                                get: {
                                    selectedClip?.sourceStart ?? 0
                                },
                                set: { value in
                                    updateSelectedClip {
                                        $0.sourceStart = min(
                                            value,
                                            max(0, $0.sourceEnd - 0.1)
                                        )
                                    }
                                }
                            ),
                            in: 0...max(clip.sourceDuration, 0.1)
                        )
                        .tint(silver)
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("TRIM END")
                            Spacer()
                            Text(timeString(clip.sourceEnd))
                                .monospacedDigit()
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)

                        Slider(
                            value: Binding(
                                get: {
                                    selectedClip?.sourceEnd ?? 0
                                },
                                set: { value in
                                    updateSelectedClip {
                                        $0.sourceEnd = max(
                                            value,
                                            $0.sourceStart + 0.1
                                        )
                                    }
                                }
                            ),
                            in: 0...max(clip.sourceDuration, 0.1)
                        )
                        .tint(silver)
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack(spacing: 10) {
                    toolButton("Split", icon: "scissors") {
                        splitSelectedClip()
                    }

                    toolButton("Delete", icon: "trash") {
                        deleteSelectedClip()
                    }
                }

                HStack(spacing: 10) {
                    toolButton("Move left", icon: "arrow.left") {
                        moveSelectedClip(by: -1)
                    }

                    toolButton("Move right", icon: "arrow.right") {
                        moveSelectedClip(by: 1)
                    }
                }

            } else {
                VStack(spacing: 9) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 23))
                        .foregroundStyle(silver.opacity(0.7))

                    Text("Select a clip to edit")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)

                    Text("Your editing controls will appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
        .padding(15)
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
    }

    // MARK: - Export

    private var exportButton: some View {
        VStack(spacing: 13) {
            Button {
                Task {
                    await exportProject()
                }
            } label: {
                HStack(spacing: 9) {
                    if isExporting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Text(isExporting ? "EXPORTING..." : "EXPORT VIDEO")
                }
                .font(.system(size: 13, weight: .bold))
                .tracking(1)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(17)
                .background(silver)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .disabled(clips.isEmpty || isExporting)
            .opacity(clips.isEmpty ? 0.45 : 1)

            if let exportedURL {
                ShareLink(item: exportedURL) {
                    Label(
                        "Save or share exported video",
                        systemImage: "square.and.arrow.up"
                    )
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(silver)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("AVI STUDIO")

            Spacer()

            Text("CREATIVITY WITHOUT LIMITS")
        }
        .font(.system(size: 8, weight: .semibold))
        .tracking(2)
        .foregroundStyle(.gray.opacity(0.6))
        .padding(.top, 5)
    }

    // MARK: - Tool Button

    private func toolButton(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17))

                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(silver)
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(secondaryPanel)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Camera Roll Import

    @MainActor
    private func importFromPhotos(
        _ items: [PhotosPickerItem]
    ) async {
        for item in items {
            do {
                guard let movie = try await item.loadTransferable(
                    type: ImportedMovie.self
                ) else {
                    showError("Could not load one of your Camera Roll videos.")
                    continue
                }

                await importVideos([movie.url])

            } catch {
                showError(
                    "Camera Roll import failed: \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Files and Video Import

    @MainActor
    private func importVideos(_ urls: [URL]) async {
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()

            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let folder = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                )[0]
                .appendingPathComponent("AVIStudioMedia")

                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )

                let ext = url.pathExtension.isEmpty
                    ? "mov"
                    : url.pathExtension

                let destination = folder
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext)

                try FileManager.default.copyItem(
                    at: url,
                    to: destination
                )

                let asset = AVURLAsset(url: destination)

                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)

                let videoTracks = try await asset.loadTracks(
                    withMediaType: .video
                )

                guard !videoTracks.isEmpty,
                      seconds.isFinite,
                      seconds > 0 else {
                    throw exportError(
                        "This file does not contain a usable video."
                    )
                }

                let clip = EditorClip(
                    url: destination,
                    name: url.lastPathComponent,
                    sourceDuration: seconds,
                    sourceStart: 0,
                    sourceEnd: seconds
                )

                clips.append(clip)

                if selectedClipID == nil {
                    selectClip(clip)
                }

            } catch {
                showError(
                    "Could not import \(url.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Clip Selection

    private func selectClip(_ clip: EditorClip) {
        selectedClipID = clip.id

        let newPlayer = AVPlayer(url: clip.url)
        player = newPlayer

        newPlayer.seek(
            to: CMTime(
                seconds: clip.sourceStart,
                preferredTimescale: 600
            )
        )

        newPlayer.pause()
    }

    // MARK: - Update Clip

    private func updateSelectedClip(
        _ update: (inout EditorClip) -> Void
    ) {
        guard let index = selectedIndex else {
            return
        }

        update(&clips[index])
    }

    // MARK: - Split Clip

    private func splitSelectedClip() {
        guard let index = selectedIndex else {
            return
        }

        let clip = clips[index]
        let midpoint = (
            clip.sourceStart + clip.sourceEnd
        ) / 2

        guard midpoint - clip.sourceStart > 0.1,
              clip.sourceEnd - midpoint > 0.1 else {
            showError("This clip is too short to split.")
            return
        }

        var first = clip
        first.id = UUID()
        first.sourceEnd = midpoint

        var second = clip
        second.id = UUID()
        second.sourceStart = midpoint

        clips.remove(at: index)

        clips.insert(
            contentsOf: [first, second],
            at: index
        )

        selectClip(first)
    }

    // MARK: - Delete Clip

    private func deleteSelectedClip() {
        guard let index = selectedIndex else {
            return
        }

        clips.remove(at: index)

        player = nil
        selectedClipID = nil

        if let next = clips.first {
            selectClip(next)
        }
    }

    // MARK: - Reorder Clips

    private func moveSelectedClip(by offset: Int) {
        guard let index = selectedIndex else {
            return
        }

        let newIndex = index + offset

        guard clips.indices.contains(newIndex) else {
            return
        }

        clips.swapAt(index, newIndex)
    }

    // MARK: - Export Project

    @MainActor
    private func exportProject() async {
        guard !clips.isEmpty else {
            return
        }

        isExporting = true
        exportedURL = nil

        defer {
            isExporting = false
        }

        do {
            let composition = AVMutableComposition()

            guard let videoCompositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
                throw exportError("Could not create the video track.")
            }

            let audioCompositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            var cursor = CMTime.zero

            for clip in clips {
                let asset = AVURLAsset(url: clip.url)

                let sourceVideoTracks = try await asset.loadTracks(
                    withMediaType: .video
                )

                guard let sourceVideoTrack = sourceVideoTracks.first else {
                    continue
                }

                let start = CMTime(
                    seconds: clip.sourceStart,
                    preferredTimescale: 600
                )

                let end = CMTime(
                    seconds: clip.sourceEnd,
                    preferredTimescale: 600
                )

                let range = CMTimeRange(
                    start: start,
                    end: end
                )

                try videoCompositionTrack.insertTimeRange(
                    range,
                    of: sourceVideoTrack,
                    at: cursor
                )

                let sourceAudioTracks = try await asset.loadTracks(
                    withMediaType: .audio
                )

                if let sourceAudioTrack = sourceAudioTracks.first,
                   let audioCompositionTrack {
                    try audioCompositionTrack.insertTimeRange(
                        range,
                        of: sourceAudioTrack,
                        at: cursor
                    )
                }

                cursor = CMTimeAdd(
                    cursor,
                    range.duration
                )
            }

            guard CMTimeGetSeconds(cursor) > 0 else {
                throw exportError("There is no video to export.")
            }

            guard let session = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetHighestQuality
            ) else {
                throw exportError("Could not create the export session.")
            }

            let output = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "AVI-STUDIO-\(UUID().uuidString).mp4"
                )

            session.outputURL = output
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in

                session.exportAsynchronously {
                    switch session.status {
                    case .completed:
                        continuation.resume()

                    case .failed, .cancelled:
                        continuation.resume(
                            throwing: session.error ?? exportError(
                                "Video export failed."
                            )
                        )

                    default:
                        continuation.resume(
                            throwing: exportError(
                                "The export did not complete."
                            )
                        )
                    }
                }
            }

            exportedURL = output

            showError("Your video has been exported successfully.")

        } catch {
            showError(
                "Export failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Helpers

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else {
            return "00:00"
        }

        let total = max(0, Int(seconds))
        let minutes = total / 60
        let remaining = total % 60

        return String(
            format: "%02d:%02d",
            minutes,
            remaining
        )
    }

    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    private func exportError(_ message: String) -> NSError {
        NSError(
            domain: "AVIStudio",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }
}
