//
//  IFProjectFileTests.swift
//  InformTests
//

import XCTest

final class IFProjectFileTests: XCTestCase {

    /// A project's UUID is the whole of its uuid.txt, which doesn't end with a NUL. Reading
    /// past its end isn't seen in a normal run, as the bytes after it are usually zero, but
    /// Address Sanitizer reports it.
    func testReadsTheUUIDFromItsFileAlone() throws {
        let uuid = "8C5D5A49-2B0E-4C6B-9D3A-6F1E2A7B4C90"
        let project = FileWrapper(directoryWithFileWrappers: [
            "uuid.txt": FileWrapper(regularFileWithContents: Data(uuid.utf8))
        ])

        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project))

        XCTAssertEqual(projectFile.loadUUID, uuid)
    }

    /// Reloading the Source folder when it's missing on disk leaves the project without one.
    func testReplacingTheSourceFolderWithNothingRemovesIt() throws {
        let source = FileWrapper(directoryWithFileWrappers: [:])
        source.preferredFilename = "Source"
        let project = FileWrapper(directoryWithFileWrappers: ["Source": source])
        let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project))

        projectFile.replaceSourceDirectoryWrapper(nil)

        XCTAssertNil(project.fileWrappers?["Source"])
    }
}
