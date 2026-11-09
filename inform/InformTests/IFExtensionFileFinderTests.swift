//
//  IFExtensionFileFinderTests.swift
//  InformTests
//

import XCTest

/// Finding the file of an extension that a source link or a search names
final class IFExtensionFileFinderTests: XCTestCase {

    /// An extensions manager whose authors have the files given
    private final class ExtensionsManager: IFExtensionsManager {
        var filesByAuthor: [String: [String]] = [:]
        private(set) var authorsAskedFor: [String] = []

        override func filesInExtension(withName name: String) -> [String] {
            authorsAskedFor.append(name)
            return filesByAuthor[name] ?? []
        }
    }

    private let manager = ExtensionsManager()
    private let locksmith = "/Library/Inform/Extensions/Emily Short/Locksmith.i7x"

    override func setUp() {
        super.setUp()
        manager.filesByAuthor["Emily Short"] = ["/Library/Inform/Extensions/Emily Short/Basic Screen Effects.i7x",
                                                locksmith]
    }

    private func file(_ name: String) -> String? {
        return IFExtensionFileFinder.file(forExtension: name, extensionsManager: manager)
    }

    /// A new temporary folder, removed after the test
    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        return folder
    }

    func testFindsAnExtensionByItsAuthorAndFileName() {
        XCTAssertEqual(file("Emily Short/Locksmith.i7x"), locksmith)
        XCTAssertEqual(manager.authorsAskedFor, ["Emily Short"])
    }

    func testTheFileNameIsInAnyCase() {
        XCTAssertEqual(file("Emily Short/locksmith.I7X"), locksmith)
    }

    func testAnExtensionTheAuthorDoesntHaveIsNotFound() {
        XCTAssertNil(file("Emily Short/Ballpoint.i7x"))
        XCTAssertNil(file("Graham Nelson/Locksmith.i7x"))
    }

    func testAFileGivenInFullIsFoundIfItsThere() throws {
        let extensionFile = try makeFolder().appendingPathComponent("Locksmith.i7x")
        try Data().write(to: extensionFile)

        XCTAssertEqual(file(extensionFile.path), extensionFile.path)
        XCTAssertNil(file(extensionFile.deletingLastPathComponent().appendingPathComponent("Ballpoint.i7x").path))
        XCTAssertEqual(manager.authorsAskedFor, [])
    }

    func testANameOfAnotherFormIsNotFound() {
        XCTAssertNil(file("Locksmith.i7x"))
        XCTAssertNil(file("Extensions/Emily Short/Locksmith.i7x"))
        XCTAssertEqual(manager.authorsAskedFor, [])
    }
}
