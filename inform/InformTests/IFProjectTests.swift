//
//  IFProjectTests.swift
//  InformTests
//

import XCTest

final class IFProjectTests: XCTestCase {

    private let lines = ["\"Line Endings\" by Inform.", "", "The Kitchen is a room."]

    /// The text of a source file, as Inform shows it once the file is opened on its own.
    /// (The file's document unregisters its text when it goes.)
    private func openedSourceFile(_ contents: String) throws -> String {
        let file = IFSingleFile()
        try file.read(from: Data(contents.utf8), ofType: "org.inform-fiction.source.inform7")
        return file.storage.string
    }

    /// The text of a project's source file, as Inform shows it once the project is opened.
    private func openedProject(_ contents: String) throws -> String {
        // The project is made in a temporary folder, as opening it makes a materials folder beside it
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let projectURL = folder.appendingPathComponent("Line Endings.inform")
        let sourceURL = projectURL.appendingPathComponent("Source")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: sourceURL.appendingPathComponent("story.ni"))

        let project = try IFProject(contentsOf: projectURL, ofType: "org.inform-fiction.project")
        let storage = try XCTUnwrap(project.sourceFiles?["story.ni"])
        IFSyntaxManager.unregisterTextStorage(storage)
        return storage.string
    }

    /// A file with Windows line endings opens with one line break per line, not two.
    func testWindowsLineEndings() throws {
        let contents = lines.joined(separator: "\r\n")
        XCTAssertEqual(try openedProject(contents), lines.joined(separator: "\n"))
        XCTAssertEqual(try openedSourceFile(contents), lines.joined(separator: "\n"))
    }

    func testOldMacLineEndings() throws {
        let contents = lines.joined(separator: "\r")
        XCTAssertEqual(try openedProject(contents), lines.joined(separator: "\n"))
        XCTAssertEqual(try openedSourceFile(contents), lines.joined(separator: "\n"))
    }

    func testUnixLineEndings() throws {
        let contents = lines.joined(separator: "\n")
        XCTAssertEqual(try openedProject(contents), contents)
        XCTAssertEqual(try openedSourceFile(contents), contents)
    }
}
