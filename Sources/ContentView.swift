
import SwiftUI
import AVKit
import AVFoundation
import UniformTypeIdentifiers

struct EditorClip: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let sourceDuration: Double
    var sourceStart: Double
    var sourceEnd: Double

    var duration: Double {
        max(0, sourceEnd - sourceStart)
    }
}

struct ContentView: View {
    @State private var clips: [EditorClip] = []
    @State private var selectedClipID: UUID?
    @State private var player: AVPlayer?

    @State private var showingImporter = false
    @State private var isExporting = false
    @State private var exportedURL: URL?

    @State private var alertMessage = ""
    @State private var showingAlert = false

    private let gold = Color(red: 0.84, green: 0.76, blue: 0.60)
    private let background = Color(red: 0.045, green: 0.045, blue: 0.045)
    private let panel = Color(red: 0.105, green: 0.105, blue: 0.105)

    private var selectedIndex: Int? {
        clips.firstIndex { $0.id == selectedClipID }
    }

    private var selectedClip: EditorClip? {
        guard let index = selectedIndex else { return nil }
        return clips[index]
    }

    private var totalDuration: Double {
        clips.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    header

                    preview

                    importButton

                    timeline

                    editingControls

                    exportButton
                }
                .padding(16)
            }
            .background(background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("AVI  STUDIO")
                        .font(.system(size: 15, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(gold)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
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
            .alert("AVI STUDIO", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .tint(gold)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR CREATIVE SPACE")
                .font(.system(size: 10, weight: .bold))
                .tracking(3)
                .foregroundStyle(gold)

            Text("Make something\nbeautiful.")
                .font(.system(size: 34, design: .serif))
                .foregroundStyle(.white)

            HStack {
                Text("Your ideas. Your creation.")
                    .foregroundStyle(.gray)

                Spacer()

                Text(timeString(totalDuration))
                    .foregroundStyle(gold)
                    .monospacedDigit()
            }
            .font(.system(size: 12))
        }
    }

    private var preview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PREVIEW")
                    .tracking(2)

                Spacer()

                Text("AVI STUDIO")
                    .foregroundStyle(gold)
            }
            .font(.system(size: 10, weight: .semibold))
            .padding(13)

            ZStack {
                Color.black

                if let player {
                    VideoPlayer(player: player)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 35))
                            .foregroundStyle(gold)

                        Text("Your canvas awaits")
                            .foregroundStyle(.white)

                        Text("Import a video to begin editing.")
                            .font(.system(size: 11))
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(height: 230)
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
            .foregroundStyle(gold)
            .padding(15)
        }
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private var importButton: some View {
        Button {
            showingImporter = true
        } label: {
            Label("Import videos", systemImage: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(15)
                .background(gold)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                Text("Your timeline is empty.")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(25)
                    .background(Color.white.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(clips) { clip in
                            Button {
                                selectClip(clip)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(systemName: "film")
                                        .font(.system(size: 20))
                                        .foregroundStyle(gold)

                                    Text(clip.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                        .foregroundStyle(.white)

                                    Text(timeString(clip.duration))
                                        .font(.system(size: 9))
                                        .foregroundStyle(.gray)
                                }
                                .padding(10)
                                .frame(width: 115, height: 82, alignment: .leading)
                                .background(
                                    selectedClipID == clip.id
                                    ? gold.opacity(0.18)
                                    : Color.white.opacity(0.045)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(
                                            selectedClipID == clip.id
                                            ? gold
                                            : Color.clear,
                                            lineWidth: 1.5
                                        )
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack {
                Label("VIDEO", systemImage: "film")
                Spacer()
                Text(timeString(totalDuration))
            }
            .font(.system(size: 10))
            .foregroundStyle(gold)
        }
        .padding(14)
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private var editingControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("EDITING TOOLS")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)

            if let clip = selectedClip {
                VStack(alignment: .leading, spacing: 12) {
                    Text(clip.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(gold)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("TRIM START")
                            Spacer()
                            Text(timeString(clip.sourceStart))
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
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("TRIM END")
                            Spacer()
                            Text(timeString(clip.sourceEnd))
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
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.1))

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
                Text("Select a clip to access editing tools.")
                    .font(.system(size: 12))
                    .foregroundStyle(.gray)
            }
        }
        .padding(15)
        .background(panel)
        .clipShape(RoundedRectangle(cornerRadius: 13))
    }

    private var exportButton: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await exportProject()
                }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Text(isExporting ? "EXPORTING..." : "EXPORT VIDEO")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(gold)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(clips.isEmpty || isExporting)

            if let exportedURL {
                ShareLink(item: exportedURL) {
                    Label("Save or share exported video", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundStyle(gold)
                }
            }
        }
    }

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
                    .font(.system(size: 10))
            }
            .foregroundStyle(gold)
            .frame(maxWidth: .infinity)
            .padding(13)
            .background(Color.white.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    // MARK: - Import

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
                )[0].appendingPathComponent("AVIStudioMedia")

                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )

                let destination = folder
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)

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
                    throw NSError(
                        domain: "AVIStudio",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "This file does not contain a usable video."
                        ]
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
                showError("Could not import \(url.lastPathComponent): \(error.localizedDescription)")
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

    private func updateSelectedClip(
        _ update: (inout EditorClip) -> Void
    ) {
        guard let index = selectedIndex else { return }

        update(&clips[index])
    }

    // MARK: - Split

    private func splitSelectedClip() {
        guard let index = selectedIndex else { return }

        let clip = clips[index]
        let midpoint = (clip.sourceStart + clip.sourceEnd) / 2

        guard midpoint - clip.sourceStart > 0.1,
              clip.sourceEnd - midpoint > 0.1 else {
            showError("This clip is too short to split.")
            return
        }

        var first = clip
        first.sourceEnd = midpoint

        var second = clip
        second.sourceStart = midpoint

        clips.remove(at: index)
        clips.insert(contentsOf: [first, second], at: index)

        selectedClipID = first.id
        selectClip(first)
    }

    // MARK: - Delete

    private func deleteSelectedClip() {
        guard let index = selectedIndex else { return }

        clips.remove(at: index)
        player = nil
        selectedClipID = nil

        if let next = clips.first {
            selectClip(next)
        }
    }

    // MARK: - Reorder

    private func moveSelectedClip(by offset: Int) {
        guard let index = selectedIndex else { return }

        let newIndex = index + offset

        guard clips.indices.contains(newIndex) else { return }

        clips.swapAt(index, newIndex)
    }

    // MARK: - Export

    @MainActor
    private func exportProject() async {
        guard !clips.isEmpty else { return }

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

                cursor = CMTimeAdd(cursor, range.duration)
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
                .appendingPathComponent("AVI-STUDIO-\(UUID().uuidString).mp4")

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
            showError("Export failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "00:00" }

        let total = max(0, Int(seconds))
        let minutes = total / 60
        let remaining = total % 60

        return String(format: "%02d:%02d", minutes, remaining)
    }

    private func showError(_ message: String) {
        alertMessage = message
        showingAlert = true
    }

    private func exportError(_ message: String) -> NSError {
        NSError(
            domain: "AVIStudioExport",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }
}
