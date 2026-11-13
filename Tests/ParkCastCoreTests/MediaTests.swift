import XCTest
@testable import ParkCastCore

final class MediaTests: XCTestCase {
    func testAddressesDefaultToHTTPSAndPreserveSignedQuery() throws {
        XCTAssertEqual(try WebAddress.parse(" example.com/video.mp4?token=a%2Fb&x=1 ").absoluteString,
                       "https://example.com/video.mp4?token=a%2Fb&x=1")
    }

    func testAddressesRejectDangerousSchemesAndCredentials() {
        for input in ["", "   ", "https://", "javascript://alert", "file:///tmp/movie.mp4",
                      "http://example.com/video.mp4", "https://name:secret@example.com/video", "not a url"] {
            XCTAssertThrowsError(try WebAddress.parse(input), input)
        }
    }

    func testPlaylistHandlesBOMCRLFQuotedCommasRelativeURLsAndDuplicates() throws {
        let source = "\u{FEFF}#EXTM3U\r\n#EXTINF:-1 group-title=\"News, world\",World, live\r\nstream.m3u8\r\n#EXTINF:-1,Duplicate\r\nstream.m3u8\r\nhttps://cdn.example.com/second.mp4\r\n"
        let result = try M3UParser.parse(source, relativeTo: URL(string: "https://example.com/channels/list.m3u")!)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].title, "World, live")
        XCTAssertEqual(result[0].location, "https://example.com/channels/stream.m3u8")
        XCTAssertEqual(result[1].title, "second.mp4")
    }

    func testRejectedEntryDoesNotLeakItsTitleToTheNextEntry() throws {
        let result = try M3UParser.parse("#EXTINF:-1,Secret\nhttp://example.com/no.mp4\nhttps://example.com/yes.mp4")
        XCTAssertEqual(result[0].title, "yes.mp4")
    }

    func testHLSManifestIsNotImportedAsAListOfChannels() {
        for text in ["#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=128000\nlow.m3u8",
                     "#EXTM3U\n#EXT-X-TARGETDURATION:10\nsegment.ts"] {
            XCTAssertThrowsError(try M3UParser.parse(text)) { XCTAssertTrue($0 is MediaError) }
        }
    }

    func testEmptyUnsafeAndOversizedPlaylists() {
        XCTAssertThrowsError(try M3UParser.parse("#EXTM3U\nfile:///private/movie.mp4\nhttp://example.com/video.mp4"))
        XCTAssertThrowsError(try M3UParser.parse(String(repeating: "a", count: M3UParser.maximumBytes + 1)))
        let tooMany = (0...M3UParser.maximumEntries).map { "https://example.com/\($0).mp4" }.joined(separator: "\n")
        XCTAssertThrowsError(try M3UParser.parse(tooMany))
    }

    func testExactlyOneThousandEntriesIsAllowed() throws {
        let source = (0..<1_000).map { "https://example.com/\($0).mp4" }.joined(separator: "\n")
        XCTAssertEqual(try M3UParser.parse(source).count, 1_000)
    }

    func testLocalEntriesCannotEscapeTheirStorageDirectory() throws {
        let directory = URL(fileURLWithPath: "/sandbox/Library/ParkCast")
        for filename in ["../secret", "/etc/passwd", "nested/video.mp4", "..\\secret", ".", "..", ""] {
            let entry = MediaEntry(title: "Test", location: filename, kind: .file)
            XCTAssertThrowsError(try entry.url(in: directory), filename)
        }
        let safe = MediaEntry(title: "Test", location: "123.mp4", kind: .file)
        XCTAssertEqual(try safe.url(in: directory).path, "/sandbox/Library/ParkCast/123.mp4")
    }

    func testLibraryRoundTripPreservesIDsAndKinds() throws {
        let original = MediaEntry(title: "A saved video", location: "uuid.mp4", kind: .file)
        let decoded = try JSONDecoder().decode(MediaEntry.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(original, decoded)
    }
}
