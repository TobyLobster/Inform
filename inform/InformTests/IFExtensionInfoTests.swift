//
//  IFExtensionInfoTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFExtensionInfoTests: XCTestCase {
    private func info(_ displayName: String = "Locksmith",
                      filepath: String? = "/Extensions/Emily Short/Locksmith.i7x",
                      author: String = "Emily Short",
                      version: String? = "v12",
                      isBuiltIn: Bool = false) -> IFExtensionInfo {
        return IFExtensionInfo(displayName: displayName, filepath: filepath, author: author,
                               version: version, isBuiltIn: isBuiltIn)
    }

    func testAnInfoKeepsWhatItsGiven() {
        let locksmith = info(isBuiltIn: true)

        XCTAssertEqual(locksmith.displayName, "Locksmith")
        XCTAssertEqual(locksmith.filepath, "/Extensions/Emily Short/Locksmith.i7x")
        XCTAssertEqual(locksmith.author, "Emily Short")
        XCTAssertEqual(locksmith.version, "v12")
        XCTAssertTrue(locksmith.isBuiltIn)
    }

    func testCanonicalTitles() {
        let titles = [
            "Locksmith": "Locksmith",
            "The Locksmith": "Locksmith",
            "the locksmith": "locksmith",
            "A Locksmith": "Locksmith",
            "An Old Locksmith": "Old Locksmith",
            "Theatre": "Theatre",
            "Another": "Another",
            "Locksmith (for Glulx only)": "Locksmith",
            "The Locksmith (for Glulx only)": "Locksmith",
            "Locksmith (old) (new)": "Locksmith",
            "Locksmith(for Glulx only)": "Locksmith(for Glulx only)",
            "Locksmith (old) and new": "Locksmith (old) and new",
            "Lo (x)": "Lo",
            // A bracket straight after the first letter is kept
            "L (x)": "L (x)",
        ]

        for (title, canonical) in titles {
            XCTAssertEqual(IFExtensionInfo.canonicalTitle(title), canonical, title)
        }
    }

    func testVersions() {
        XCTAssertEqual(info(version: "v12").safeVersion, "v12")
        XCTAssertEqual(info(version: "").safeVersion, "")
        XCTAssertEqual(info(version: nil).safeVersion, "Version (none)")

        XCTAssertEqual(info(version: "12.1.0").semver.to_text, IFSemVer(string: "12.1.0").to_text)
        XCTAssertEqual(info(version: "v12").semver.to_text, IFSemVer(string: "v12").to_text)
        XCTAssertEqual(info(version: nil).semver.to_text, IFSemVer().to_text)
    }

    func testOrder() {
        // By name, ignoring case
        XCTAssertEqual(info("apple").caseInsensitiveCompare(info("Banana")), .orderedAscending)
        XCTAssertEqual(info("Banana").caseInsensitiveCompare(info("apple")), .orderedDescending)

        // Then by author, ignoring case
        XCTAssertEqual(info("Locksmith", author: "Anon").caseInsensitiveCompare(info("LOCKSMITH", author: "emily Short")),
                       .orderedAscending)

        // Then by file, minding case
        XCTAssertEqual(info(filepath: "/b").caseInsensitiveCompare(info(filepath: "/a", author: "EMILY SHORT")), .orderedDescending)
        XCTAssertEqual(info(filepath: "/a").caseInsensitiveCompare(info(filepath: "/B")), .orderedDescending)
        XCTAssertEqual(info().caseInsensitiveCompare(info(version: "v1", isBuiltIn: true)), .orderedSame)

        // With no file, it's the same as any other, but a file comes after no file
        XCTAssertEqual(info(filepath: nil).caseInsensitiveCompare(info(filepath: "/a")), .orderedSame)
        XCTAssertEqual(info(filepath: nil).caseInsensitiveCompare(info(filepath: nil)), .orderedSame)
        XCTAssertEqual(info(filepath: "/a").caseInsensitiveCompare(info(filepath: nil)), .orderedDescending)
    }

    func testEquality() {
        XCTAssertTrue(info().isEqual(info()))
        XCTAssertTrue(info(filepath: nil, version: nil).isEqual(info(filepath: nil, version: nil)))

        XCTAssertFalse(info().isEqual(info("Keys")))
        XCTAssertFalse(info().isEqual(info(filepath: "/Extensions/Locksmith.i7x")))
        XCTAssertFalse(info().isEqual(info(filepath: nil)))
        XCTAssertFalse(info(filepath: nil).isEqual(info()))
        XCTAssertFalse(info().isEqual(info(author: "emily short")))
        XCTAssertFalse(info().isEqual(info(version: "v13")))
        XCTAssertFalse(info().isEqual(info(version: nil)))
        XCTAssertFalse(info().isEqual(info(isBuiltIn: true)))

        // Text is compared as it's written, so an accent written two ways makes two names
        XCTAssertFalse(info("Caf\u{E9}").isEqual(info("Cafe\u{301}")))

        XCTAssertFalse(info().isEqual(nil))
        XCTAssertFalse(info().isEqual("Locksmith"))
    }

    func testEqualInfosHashAlike() {
        // Kept alive together, so that no two share an address
        let locksmiths = (0..<20).map { _ in info() }
        let unknowns = (0..<20).map { _ in info(filepath: nil, version: nil) }

        XCTAssertEqual(Set(locksmiths.map(\.hash)).count, 1)
        XCTAssertEqual(Set(unknowns.map(\.hash)).count, 1)
        XCTAssertEqual(NSSet(array: locksmiths + unknowns + [info("Keys")]).count, 3)
    }

    // MARK: - Its source

    /// A new temporary folder, removed after the test
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    /// Makes an empty file, and the folders it's in
    @discardableResult
    private func make(_ path: String, in folder: URL) throws -> String {
        let file = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: file)
        return file.path
    }

    func testAnExtensionsSourceIsItsFile() {
        XCTAssertFalse(info().isLiterate)
        XCTAssertEqual(info().sourceFiles, ["/Extensions/Emily Short/Locksmith.i7x"])

        let folderExtension = info(filepath: "/Extensions/Emily Short/Locksmith-v12.i7xd/Source/Locksmith.i7x")
        XCTAssertFalse(folderExtension.isLiterate)
        XCTAssertEqual(folderExtension.sourceFiles, ["/Extensions/Emily Short/Locksmith-v12.i7xd/Source/Locksmith.i7x"])

        // Only a folder extension's contents page makes it literate
        XCTAssertFalse(info(filepath: "/Extensions/Emily Short/Contents.w").isLiterate)

        XCTAssertFalse(info(filepath: nil).isLiterate)
        XCTAssertEqual(info(filepath: nil).sourceFiles, [])
    }

    /// A literate extension's source is its contents page and its sections, which Find in Files searches
    func testALiterateExtensionsSourceIsItsContentsAndSections() throws {
        let folder = try makeFolder().appendingPathComponent("Locksmith-v12.i7xd")
        let contents = try make("Source/Contents.w", in: folder)
        let preamble = try make("Source/Sections/Preamble.w", in: folder)
        let actions = try make("Source/Sections/actions.w", in: folder)
        let doors = try make("Source/Chapter 2/Doors.w", in: folder)

        // None of these is part of it
        try make("Source/Sections/.Hidden.w", in: folder)
        try make("Source/.Hidden/Hidden.w", in: folder)
        try make("Source/Sections/Notes.txt", in: folder)
        try make("Source/Folder.w/Inside.txt", in: folder)
        try make("Documentation/Documentation.w", in: folder)

        let locksmith = info(filepath: contents)
        XCTAssertTrue(locksmith.isLiterate)
        XCTAssertEqual(locksmith.sourceFiles, [contents, doors, actions, preamble])
    }
}
