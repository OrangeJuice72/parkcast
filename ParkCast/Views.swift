import SwiftUI
import UniformTypeIdentifiers

private let canvas = Color(red: 0.045, green: 0.055, blue: 0.065)
private let panel = Color(red: 0.085, green: 0.105, blue: 0.115)

@MainActor
struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LibraryStore
    init(model: AppModel) { self.model = model; library = model.library }

    var body: some View {
        TabView(selection: $model.tab) {
            WatchView(model: model)
                .tabItem { Label("Watch", systemImage: "play.rectangle") }.tag(0)
            LibraryView(model: model, library: library)
                .tabItem { Label("Library", systemImage: "square.stack") }.tag(1)
            ConnectionView(model: model, playback: model.playback)
                .tabItem { Label("Connect", systemImage: "airplayvideo") }.tag(2)
        }
        .sheet(isPresented: $model.showingBrowser) {
            BrowserScreen(model: model, browser: model.browser)
        }
        .sheet(isPresented: $model.showingPlayer) {
            PlayerScreen(playback: model.playback)
        }
        .alert("Library", isPresented: Binding(get: { library.issue != nil }, set: { if !$0 { library.issue = nil } })) {
            Button("OK") { library.issue = nil }
        } message: { Text(library.issue ?? "") }
    }
}

@MainActor
struct WatchView: View {
    @ObservedObject var model: AppModel
    @State private var address = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Label("PARKCAST", systemImage: "play.rectangle.fill")
                            .font(.headline).tracking(3).foregroundStyle(.mint)
                        Spacer()
                        Text("NO SUBSCRIPTION").font(.caption2.bold()).foregroundStyle(.secondary)
                    }
                    NowPlayingStrip(model: model, playback: model.playback)
                    VStack(alignment: .leading, spacing: 12) {
                        Label("PARKED MOMENTS", systemImage: "parkingsign.circle")
                            .font(.caption.bold()).tracking(2).foregroundStyle(.mint)
                        Text("Make the most\nof the pause.")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Your videos. Your screen. Your time.")
                            .foregroundStyle(.secondary)
                        Button { model.tab = 2 } label: {
                            HStack {
                                Image(systemName: "airplayvideo")
                                Text("Connect a display").fontWeight(.semibold)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }.padding().background(.mint, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                        }.padding(.top, 8)
                    }
                    .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                    .background(LinearGradient(colors: [Color(red: 0.10, green: 0.20, blue: 0.19), panel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 26))

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Open a service", detail: "Uses each service’s website")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            service("YouTube", caption: "Videos & live", symbol: "play.rectangle.fill", color: .red, address: "https://www.youtube.com")
                            service("Netflix", caption: "Open website", symbol: "film", color: .red, address: "https://www.netflix.com")
                            service("Disney+", caption: "Open website", symbol: "sparkles.tv", color: .cyan, address: "https://www.disneyplus.com")
                            Button { model.tab = 1 } label: {
                                serviceLabel("Your videos", caption: "Files & streams", symbol: "folder", color: .mint)
                            }.buttonStyle(.plain)
                        }
                        Text("Service sign-in and playback restrictions still apply. A shortcut doesn’t guarantee video output to your car.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Go somewhere else", detail: "Open a secure website")
                        HStack {
                            TextField("https://", text: $address)
                                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .submitLabel(.go).onSubmit { model.browse(address) }
                                .accessibilityLabel("Website address")
                            Button { model.browse(address) } label: {
                                Image(systemName: "arrow.right.circle.fill").font(.title)
                            }.disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityLabel("Open website")
                        }.padding(16).background(panel, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Button { model.playTest() } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.rectangle.stack").font(.title2).foregroundStyle(.mint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Try a video test").font(.headline)
                                Text("Apple test stream · internet required").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle").font(.title2)
                        }.padding(18).background(panel, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                    Text("Use video on the car display while parked.")
                        .font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(22)
            }.background(canvas).toolbar(.hidden, for: .navigationBar)
        }
    }

    private func service(_ title: String, caption: String, symbol: String, color: Color, address: String) -> some View {
        Button { model.browse(address) } label: {
            serviceLabel(title, caption: caption, symbol: symbol, color: color)
        }.buttonStyle(.plain)
    }

    private func serviceLabel(_ title: String, caption: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(18).frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
            .background(panel, in: RoundedRectangle(cornerRadius: 18))
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

@MainActor
struct LibraryView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var library: LibraryStore
    @State private var query = ""
    @State private var showAdd = false
    @State private var showImport = false
    @State private var importPlaylist = false
    @State private var pendingDelete: MediaEntry?
    private var filtered: [MediaEntry] {
        library.entries.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        NavigationStack {
            List {
                if library.importing {
                    HStack { ProgressView(); Text("Importing…").padding(.leading, 8) }
                }
                if filtered.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "A place for your favorites" : "No matches",
                                           systemImage: "square.stack",
                                           description: Text(query.isEmpty ? "Import a video, save a website, or add a direct video link." : "Try another title."))
                        .listRowBackground(Color.clear)
                }
                ForEach(filtered) { entry in
                    Button { model.play(entry) } label: {
                        HStack(spacing: 14) {
                            Image(systemName: entry.kind == .website ? "globe" : "play.rectangle")
                                .font(.title2).foregroundStyle(.mint).frame(width: 36)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(entry.title).foregroundStyle(.primary).lineLimit(2)
                                Text(entry.kind == .file ? "Saved on this iPhone" : URL(string: entry.location)?.host ?? "Video link")
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                    .listRowBackground(panel)
                    .swipeActions {
                        Button("Delete", role: .destructive) { pendingDelete = entry }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(canvas)
            .navigationTitle("Your library")
            .searchable(text: $query, prompt: "Find a video or website")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add a link", systemImage: "link") { showAdd = true }
                        Button("Import a video", systemImage: "folder") { importPlaylist = false; showImport = true }
                        Button("Import M3U playlist", systemImage: "list.bullet") { importPlaylist = true; showImport = true }
                    } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                        .disabled(library.importing).accessibilityLabel("Add to library")
                }
            }
            .sheet(isPresented: $showAdd) { AddLinkView(library: library) }
            .fileImporter(isPresented: $showImport, allowedContentTypes: importPlaylist
                          ? [UTType(filenameExtension: "m3u") ?? .plainText, UTType(filenameExtension: "m3u8") ?? .plainText, .plainText]
                          : [.movie, .mpeg4Movie, .quickTimeMovie]) { result in
                switch result {
                case .success(let url): Task { await library.importFile(url, playlist: importPlaylist) }
                case .failure(let error): library.issue = error.localizedDescription
                }
            }
            .confirmationDialog("Remove this item?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Remove from ParkCast", role: .destructive) {
                    if let entry = pendingDelete {
                        if entry.kind == .file { model.playback.stop() }
                        library.remove(entry)
                    }
                    pendingDelete = nil
                }
            } message: { Text("Imported copies are deleted from ParkCast. Your original files are kept.") }
        }
    }
}

@MainActor
struct AddLinkView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryStore
    @State private var address = ""
    @State private var title = ""
    @State private var kind = 0
    @State private var issue: String?
    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $kind) {
                    Text("Video link").tag(0)
                    Text("Website").tag(1)
                    Text("M3U playlist").tag(2)
                }
                TextField("https://example.com/video.mp4", text: $address)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                if kind != 2 { TextField("Title (optional)", text: $title) }
                Text(kind == 0 ? "Use a direct MP4, MOV, or HLS (.m3u8) URL. YouTube and streaming-service pages should be saved as Website."
                     : kind == 1 ? "Saved websites open in the built-in browser."
                     : "Import your own channel list. ParkCast does not provide channels or streaming subscriptions.")
                    .font(.footnote).foregroundStyle(.secondary)
                if let issue { Text(issue).foregroundStyle(.orange) }
            }
            .navigationTitle("Add a link").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(address.isEmpty)
                }
            }
        }
    }
    private func save() {
        do {
            let url = try WebAddress.parse(address)
            if kind == 2 {
                Task { await library.importPlaylist(url.absoluteString) }
            } else {
                let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                library.add(MediaEntry(title: name.isEmpty ? (url.lastPathComponent.isEmpty ? url.host! : url.lastPathComponent) : name,
                                       location: url.absoluteString, kind: kind == 0 ? .stream : .website))
            }
            dismiss()
        } catch { issue = error.localizedDescription }
    }
}

@MainActor
struct BrowserScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var model: AppModel
    @ObservedObject var browser: BrowserModel
    @State private var bookmarked = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "globe").foregroundStyle(.secondary)
                    TextField("Website address", text: $browser.address)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .submitLabel(.go).onSubmit { browser.open(browser.address) }
                    Button { browser.open(browser.address) } label: { Image(systemName: "arrow.right") }
                        .accessibilityLabel("Go to address")
                }.padding(14).background(panel)
                if browser.progress > 0 && browser.progress < 1 {
                    ProgressView(value: browser.progress).tint(.mint)
                }
                if let issue = browser.issue {
                    HStack(alignment: .top) {
                        Text(issue).font(.footnote)
                        Spacer()
                        Button { browser.issue = nil } label: { Image(systemName: "xmark.circle") }
                            .accessibilityLabel("Dismiss browser message")
                    }.padding().background(Color.orange.opacity(0.15))
                }
                BrowserSurface(model: browser)
                HStack {
                    Image(systemName: "airplayvideo").foregroundStyle(.mint)
                    Text("Start a video, then use its AirPlay control. The service and display must allow video.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(12).background(panel)
                HStack {
                    Button { browser.webView.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!browser.canGoBack).accessibilityLabel("Back")
                    Spacer()
                    Button { browser.webView.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!browser.canGoForward).accessibilityLabel("Forward")
                    Spacer()
                    Button { browser.webView.reload() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel("Reload")
                    Spacer()
                    Button {
                        guard let url = browser.webView.url, url.scheme == "https" else { return }
                        model.library.add(MediaEntry(title: browser.title, location: url.absoluteString, kind: .website))
                        bookmarked = true
                    } label: { Image(systemName: bookmarked ? "bookmark.fill" : "bookmark") }
                        .accessibilityLabel("Save website")
                    Spacer()
                    Button {
                        if let url = browser.webView.url, url.scheme == "https" { openURL(url) }
                    } label: { Image(systemName: "safari") }.accessibilityLabel("Open in Safari")
                    Spacer()
                    AirPlayPicker().frame(width: 44, height: 44).accessibilityLabel("Choose AirPlay output")
                }.font(.title3).padding(.horizontal, 24).frame(minHeight: 58).background(canvas)
            }
            .navigationTitle(browser.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { browser.pause(); dismiss() } } }
            .onChange(of: browser.address) { _, _ in bookmarked = false }
            .onDisappear { browser.pause() }
        }
    }
}

@MainActor
struct PlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var playback: PlaybackController
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    NativePlayer(player: playback.player).aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    if playback.loading { HStack { ProgressView(); Text("Loading video…") } }
                    if let issue = playback.issue {
                        Label(issue, systemImage: "exclamationmark.circle").foregroundStyle(.orange).font(.callout)
                    }
                    Text(playback.title).font(.title2.bold())
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Choose a display").font(.headline)
                            Text("Tap the AirPlay button").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        AirPlayPicker().frame(width: 60, height: 60).accessibilityLabel("Choose AirPlay output")
                    }.padding(16).background(panel, in: RoundedRectangle(cornerRadius: 18))
                    Label(playback.externalVideo ? "External video playback is active" : "External video playback is not active",
                          systemImage: playback.externalVideo ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(playback.externalVideo ? Color.mint : Color.secondary)
                    Text("Audio output: \(playback.output)").font(.footnote).foregroundStyle(.secondary)
                    Text("If you hear sound but see no video, the selected route may only support audio, the car may not allow video, or the content may restrict external playback.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Stop playback", role: .destructive) { playback.stop(); dismiss() }
                        .buttonStyle(.bordered).frame(maxWidth: .infinity)
                }.padding(22)
            }.background(canvas)
                .navigationTitle("Now playing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

@MainActor
private struct NowPlayingStrip: View {
    @ObservedObject var model: AppModel
    @ObservedObject var playback: PlaybackController
    var body: some View {
        if playback.hasMedia {
            HStack(spacing: 12) {
                Button { model.showingPlayer = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "waveform").foregroundStyle(.mint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("NOW PLAYING").font(.caption2.bold()).foregroundStyle(.secondary)
                            Text(playback.title).font(.subheadline).lineLimit(1)
                        }
                        Spacer()
                    }
                }.buttonStyle(.plain)
                Button { playback.togglePlayback() } label: {
                    Image(systemName: playback.playing ? "pause.circle.fill" : "play.circle.fill").font(.title)
                }.accessibilityLabel(playback.playing ? "Pause" : "Play")
            }.padding(16).background(panel, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

@MainActor
struct ConnectionView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var playback: PlaybackController
    @State private var clearData = false
    @State private var clearing = false
    @State private var cleared = false
    private var capability: String {
        model.carVideoSupported.map { $0 ? "Supported by this CarPlay session" : "Not supported by this CarPlay session" } ?? "Not reported by this connection"
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "car.side").font(.largeTitle).foregroundStyle(.mint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your parked cinema").font(.headline)
                            Text("2025 Sierra Denali 2500 HD").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                    Label("Connect iPhone to CarPlay while parked.", systemImage: "1.circle")
                    Label("Start the test video below.", systemImage: "2.circle")
                    Label("Tap AirPlay and select an available display.", systemImage: "3.circle")
                    Button("Play the video test", systemImage: "play.rectangle") { model.playTest() }
                } header: { Text("Start here") }
                Section {
                    diagnostic("Audio output", value: playback.output)
                    diagnostic("Native player external video", value: playback.externalVideo ? "Active" : "Not active")
                    diagnostic("CarPlay video capability", value: capability)
                    Text("Audio output does not confirm video support. Website video output is managed by the website and iOS and is not measured here.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Refresh connection", systemImage: "arrow.clockwise") { playback.refreshRoute() }
                    ShareLink(item: model.diagnosticReport) { Label("Share diagnostics", systemImage: "square.and.arrow.up") }
                } header: { Text("Connection details") }
                Section {
                    Text("Open Control Center → Screen Mirroring on your iPhone, then select a receiver listed by iOS. If your truck is absent, this option cannot mirror to it.")
                    Text("ParkCast does not provide its own whole-phone screen broadcast in this version. Protected video may remain black when mirrored.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Mirror your iPhone") }
                Section {
                    Text("Open a service in Watch and sign in on its own website. Some services require their official app or limit AirPlay. ParkCast does not unlock restricted playback.")
                    Text("Imported videos and bookmarks stay on this iPhone. Website cookies are stored by iOS WebKit. Clearing website data signs you out of websites in ParkCast.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(clearing ? "Clearing…" : "Clear website logins and data", role: .destructive) { clearData = true }
                        .disabled(clearing)
                    if cleared { Text("Website data cleared.").foregroundStyle(.mint) }
                } header: { Text("Services & privacy") }
            }
            .scrollContentBackground(.hidden).background(canvas)
            .navigationTitle("Connect")
            .confirmationDialog("Clear website data?", isPresented: $clearData) {
                Button("Clear and sign out", role: .destructive) {
                    clearing = true
                    Task {
                        await model.browser.clearWebsiteData()
                        clearing = false
                        cleared = true
                    }
                }
            } message: { Text("This signs you out of websites in ParkCast. Your saved videos and bookmarks stay.") }
        }
    }
    private func diagnostic(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.body)
        }.padding(.vertical, 3)
    }
}
