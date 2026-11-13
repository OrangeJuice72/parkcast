import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var entries: [MediaEntry] = []
    @Published var issue: String?
    @Published private(set) var importing = false
    let directory: URL
    private let indexURL: URL
    private var canWrite = true

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ParkCast", isDirectory: true)
        indexURL = directory.appendingPathComponent("library.json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: indexURL.path) {
                entries = try JSONDecoder().decode([MediaEntry].self, from: Data(contentsOf: indexURL))
            }
        } catch {
            canWrite = false
            issue = "Your saved library could not be opened. Existing files were preserved. " + error.localizedDescription
        }
    }

    func add(_ entry: MediaEntry) {
        guard !entries.contains(where: { $0.location == entry.location && $0.kind == entry.kind }) else { return }
        commit([entry] + entries)
    }

    func remove(_ entry: MediaEntry) {
        guard commit(entries.filter { $0.id != entry.id }) else { return }
        if entry.kind == .file, let url = try? entry.url(in: directory) {
            do { try FileManager.default.removeItem(at: url) }
            catch { issue = "Removed from the library, but the copied video could not be deleted: " + error.localizedDescription }
        }
    }

    func importFile(_ source: URL, playlist: Bool) async {
        guard canWrite, !importing else { return }
        importing = true
        defer { importing = false }
        let destinationDirectory = directory
        do {
            let imported = try await Task.detached(priority: .userInitiated) { () throws -> [MediaEntry] in
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                if playlist {
                    let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= M3UParser.maximumBytes else { throw MediaError.tooLarge }
                    return try M3UParser.parse(String(contentsOf: source, encoding: .utf8))
                }
                let filename = UUID().uuidString + "." + source.pathExtension.lowercased()
                let destination = destinationDirectory.appendingPathComponent(filename)
                try FileManager.default.copyItem(at: source, to: destination)
                return [MediaEntry(title: source.deletingPathExtension().lastPathComponent,
                                   location: filename, kind: .file)]
            }.value
            let existing = Set(entries.map(\.location))
            if !commit(imported.filter { !existing.contains($0.location) } + entries) {
                // Roll back only files just created by this import, never the source document.
                for entry in imported where entry.kind == .file {
                    if let url = try? entry.url(in: directory) { try? FileManager.default.removeItem(at: url) }
                }
            }
        } catch { issue = error.localizedDescription }
    }

    func importPlaylist(_ address: String) async {
        guard !importing else { return }
        importing = true
        defer { importing = false }
        do {
            let url = try WebAddress.parse(address)
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            guard response.expectedContentLength <= M3UParser.maximumBytes else { throw MediaError.tooLarge }
            var data = Data()
            for try await byte in bytes {
                guard data.count < M3UParser.maximumBytes else { throw MediaError.tooLarge }
                data.append(byte)
            }
            guard let text = String(data: data, encoding: .utf8) else { throw MediaError.emptyPlaylist }
            let imported = try M3UParser.parse(text, relativeTo: response.url ?? url)
            let existing = Set(entries.map(\.location))
            commit(imported.filter { !existing.contains($0.location) } + entries)
        } catch { issue = error.localizedDescription }
    }

    @discardableResult
    private func commit(_ updated: [MediaEntry]) -> Bool {
        guard canWrite else {
            issue = "The library is read-only because its saved index could not be opened. Existing files are preserved."
            return false
        }
        do {
            try JSONEncoder().encode(updated).write(to: indexURL, options: .atomic)
            entries = updated
            return true
        } catch {
            issue = "Could not save the library: " + error.localizedDescription
            return false
        }
    }
}
