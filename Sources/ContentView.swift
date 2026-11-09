import SwiftUI
import AVKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var showingImporter = false
    @State private var player: AVPlayer?
    @State private var selectedImage: UIImage?
    @State private var mediaName = "No media selected"
    @State private var duration: Double = 0
    @State private var playhead: Double = 0
    @State private var message = "Import a video or photo to begin."

    private let gold = Color(red: 0.84, green: 0.76, blue: 0.60)
    private let background = Color(red: 0.055, green: 0.055, blue: 0.05)
    private let panel = Color(red: 0.105, green: 0.105, blue: 0.095)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {

                    VStack(alignment: .leading, spacing: 7) {
                        Text("YOUR CREATIVE SPACE")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(gold)

                        Text("Make something\nbeautiful.")
                            .font(.system(size: 35, weight: .regular, design: .serif))
                            .foregroundStyle(.white)

                        Text("Your ideas. Your creation.")
                            .foregroundStyle(.gray)
                            .font(.system(size: 13))
                    }

                    VStack(spacing: 0) {
                        HStack {
                            Text("PREVIEW")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(2)

                            Spacer()

                            Text("AVI STUDIO")
                                .font(.system(size: 9))
                                .foregroundStyle(gold)
                        }
                        .padding()

                        ZStack {
                            Color.black

                            if let player {
                                VideoPlayer(player: player)
                            } else if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                VStack(spacing: 13) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 32))
                                        .foregroundStyle(gold)

                                    Text("Your canvas awaits.")
                                        .font(.system(size: 16))

                                    Text(message)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .frame(height: 260)
                        .clipped()
                    }
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import media", systemImage: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(gold)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("TIMELINE")
                                .tracking(2)
                                .font(.system(size: 11, weight: .semibold))

                            Spacer()

                            Text("YOUR PROJECT")
                                .font(.system(size: 9))
                                .foregroundStyle(.gray)
                        }

                        timelineTrack("VIDEO", icon: "film")
                        timelineTrack("AUDIO", icon: "waveform")
                        timelineTrack("TEXT", icon: "textformat")
                    }
                    .padding()
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("EDITING TOOLS")
                            .tracking(2)
                            .font(.system(size: 11, weight: .semibold))

                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible()),
                                count: 4
                            ),
                            spacing: 17
                        ) {
                            tool("Trim", "scissors")
                            tool("Split", "square.split.2x1")
                            tool("Crop", "crop")
                            tool("Text", "textformat")
                            tool("Audio", "waveform")
                            tool("Effects", "sparkles")
                            tool("Speed", "speedometer")
                            tool("Export", "square.and.arrow.up")
                        }
                    }
                    .padding()
                    .background(panel)
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENT PROJECT")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(gold)

                        Text(mediaName)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("AVI STUDIO · iOS EDITION")
                            .font(.system(size: 9))
                            .foregroundStyle(.gray)
                    }
                    .padding(.vertical, 8)
                }
                .padding(20)
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
                allowedContentTypes: [.movie, .mpeg4Movie, .image],
                allowsMultipleSelection: false
            ) { result in
                importMedia(result)
            }
        }
        .tint(gold)
    }

    private func timelineTrack(_ name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(gold)
                .frame(width: 22)

            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 48, alignment: .leading)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.055))
                .overlay {
                    Text(name == "VIDEO" && player != nil
                         ? mediaName : "Empty track")
                        .font(.system(size: 10))
                        .foregroundStyle(gold.opacity(0.8))
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                }
                .frame(height: 42)
        }
    }

    private func tool(_ name: String, _ icon: String) -> some View {
        Button {
            message = "\(name) tools are coming in a future update."
        } label: {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundStyle(gold)

                Text(name)
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func importMedia(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }

            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)

            try FileManager.default.copyItem(
                at: url,
                to: destination
            )

            mediaName = url.lastPathComponent

            if let type = UTType(filenameExtension: url.pathExtension),
               type.conforms(to: .image),
               let image = UIImage(contentsOfFile: destination.path) {
                selectedImage = image
                player = nil
                message = "Photo imported."
            } else {
                selectedImage = nil
                let newPlayer = AVPlayer(url: destination)
                player = newPlayer
                newPlayer.play()
                message = "Video imported."
            }

        } catch {
            message = "Import failed: \(error.localizedDescription)"
        }
    }
}
