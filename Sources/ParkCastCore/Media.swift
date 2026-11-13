import Foundation

enum MediaError: LocalizedError {
    case invalidAddress, insecureAddress, emptyPlaylist, hlsIsVideo, tooLarge, invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "Enter a complete web address, such as https://example.com/video.mp4."
        case .insecureAddress: return "Use an HTTPS address. Unencrypted HTTP links are not supported."
        case .emptyPlaylist: return "No supported HTTPS video links were found in this playlist."
        case .hlsIsVideo: return "This is an HLS video, not a channel list. Add it using Video link instead."
        case .tooLarge: return "This playlist is too large. The limit is 2 MB or 1,000 entries."
        case .invalidFile: return "This saved file is not available. Import the video again."
        }
    }
}

enum WebAddress {
    static func parse(_ input: String) throws -> URL {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else {
            throw MediaError.invalidAddress
        }
        let value = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: value),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              let url = components.url else { throw MediaError.invalidAddress }
        guard components.scheme?.lowercased() == "https" else { throw MediaError.insecureAddress }
        return url
    }

    static func isDirectVideo(_ url: URL) -> Bool {
        ["mp4", "m4v", "mov", "m3u8"].contains(url.pathExtension.lowercased())
    }
}

struct MediaEntry: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case stream, file, website }
    var id = UUID()
    var title: String
    var location: String
    var kind: Kind
    var addedAt = Date()

    func url(in directory: URL) throws -> URL {
        if kind == .file {
            // Persist only a filename; never a sandbox path or an arbitrary relative path.
            guard !location.isEmpty, location != ".", location != "..",
                  !location.contains("/"), !location.contains("\\") else { throw MediaError.invalidFile }
            return directory.appendingPathComponent(location)
        }
        return try WebAddress.parse(location)
    }
}

enum M3UParser {
    static let maximumBytes = 2 * 1024 * 1024
    static let maximumEntries = 1_000

    static func parse(_ text: String, relativeTo base: URL? = nil) throws -> [MediaEntry] {
        guard text.utf8.count <= maximumBytes else { throw MediaError.tooLarge }
        // HLS media/master manifests contain segment or variant URLs, not channel entries.
        guard !text.uppercased().contains("#EXT-X-") else { throw MediaError.hlsIsVideo }
        var title: String?
        var entries: [MediaEntry] = []
        var seen = Set<String>()
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\u{FEFF}", with: "")
            if line.hasPrefix("#EXTINF:") {
                title = displayName(in: line)
                continue
            }
            if line.isEmpty || line.hasPrefix("#") { continue }
            defer { title = nil }
            let resolved: String
            if let base, let url = URL(string: line, relativeTo: base)?.absoluteURL {
                resolved = url.absoluteString
            } else {
                // Without a base URL, relative file paths are not network streams.
                guard line.lowercased().hasPrefix("https://") else { continue }
                resolved = line
            }
            guard let url = try? WebAddress.parse(resolved), seen.insert(url.absoluteString).inserted else { continue }
            guard entries.count < maximumEntries else { throw MediaError.tooLarge }
            let name = title?.trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(MediaEntry(title: name?.isEmpty == false ? name! : url.lastPathComponent,
                                      location: url.absoluteString, kind: .stream))
        }
        guard !entries.isEmpty else { throw MediaError.emptyPlaylist }
        return entries
    }

    private static func displayName(in line: String) -> String? {
        var quoted = false
        for index in line.indices {
            if line[index] == "\"" { quoted.toggle() }
            if line[index] == ",", !quoted {
                return String(line[line.index(after: index)...])
            }
        }
        return nil
    }
}
