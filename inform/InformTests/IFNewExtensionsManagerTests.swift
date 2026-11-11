//
//  IFNewExtensionsManagerTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFNewExtensionsManagerTests: XCTestCase, @unchecked Sendable {
    private var folder: URL!

    override func setUpWithError() throws {
        try MainActor.assumeIsolated {
            folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    override func tearDownWithError() throws {
        MainActor.assumeIsolated {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private var manager: IFNewExtensionsManager {
        return IFNewExtensionsManager.shared
    }

    /// Makes an extension folder, with one file in it
    private func makeExtensionFolder(_ name: String) throws -> URL {
        let extensionURL = folder.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: extensionURL.appendingPathComponent("Source"),
                                                withIntermediateDirectories: true)
        try Data("Locksmith begins here.".utf8).write(to: extensionURL.appendingPathComponent("Source/Locksmith.i7x"))
        return extensionURL
    }

    /// Zips an extension folder
    private func zip(_ extensionURL: URL, as name: String) throws -> URL {
        let zipURL = folder.appendingPathComponent(name)
        let zipTask = Process()
        zipTask.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipTask.currentDirectoryURL = extensionURL.deletingLastPathComponent()
        zipTask.arguments = ["-q", "-r", zipURL.path, extensionURL.lastPathComponent]
        try zipTask.run()
        zipTask.waitUntilExit()
        XCTAssertEqual(zipTask.terminationStatus, 0)
        return zipURL
    }

    func testTheManagerIsShared() {
        XCTAssertTrue(IFNewExtensionsManager.shared === IFNewExtensionsManager.shared)
    }

    func testCopyingAFile() throws {
        let source = folder.appendingPathComponent("Locksmith.i7x")
        try Data("Locksmith begins here.".utf8).write(to: source)
        let destination = folder.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data().write(to: destination.appendingPathComponent("Old.i7x"))

        let result = try XCTUnwrap(manager.copy(withUnzip: source, to: destination, extensionName: "Copy.i7x"))

        XCTAssertEqual(result, destination.appendingPathComponent("Copy.i7x"))
        XCTAssertEqual(try Data(contentsOf: result), try Data(contentsOf: source))

        // What was in the folder before goes
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("Old.i7x").path))
    }

    func testCopyingAFolder() throws {
        let source = try makeExtensionFolder("Locksmith.i7xd")
        let destination = folder.appendingPathComponent("Destination/Inside")

        let result = try XCTUnwrap(manager.copy(withUnzip: source, to: destination, extensionName: "Locksmith.i7xd"))

        XCTAssertEqual(result.path, destination.appendingPathComponent("Locksmith.i7xd").path)
        XCTAssertEqual(try String(contentsOf: result.appendingPathComponent("Source/Locksmith.i7x"), encoding: .utf8),
                       "Locksmith begins here.")
    }

    func testUnzipping() throws {
        let zipURL = try zip(try makeExtensionFolder("Locksmith.i7xd"), as: "Locksmith.ZIP")
        let destination = folder.appendingPathComponent("Destination")

        let result = try XCTUnwrap(manager.copy(withUnzip: zipURL, to: destination, extensionName: "Locksmith.zip"))

        // The folder in the zip file is expected to be named after it
        XCTAssertEqual(result, destination.appendingPathComponent("Locksmith.i7xd"))
        XCTAssertEqual(try String(contentsOf: result.appendingPathComponent("Source/Locksmith.i7x"), encoding: .utf8),
                       "Locksmith begins here.")
    }

    func testAZipThatCantBeUnzipped() throws {
        let zipURL = folder.appendingPathComponent("Garbled.zip")
        try Data("Not a zip file".utf8).write(to: zipURL)

        XCTAssertNil(manager.copy(withUnzip: zipURL, to: folder.appendingPathComponent("Destination"), extensionName: "Garbled.zip"))
    }

    func testCopyingIntoAProjectsTemporaryFolder() throws {
        let source = folder.appendingPathComponent("Locksmith.i7x")
        try Data("Locksmith begins here.".utf8).write(to: source)
        let project = IFProject()
        project.fileURL = folder.appendingPathComponent("Test.inform")

        let result = try XCTUnwrap(manager.copy(withUnzip: source, toProjectTemporary: project, extensionName: "Locksmith.i7x"))

        XCTAssertEqual(result.standardizedFileURL,
                       folder.appendingPathComponent("Test.materials/Extensions/Reserved/Temporary/Locksmith.i7x").standardizedFileURL)
        XCTAssertEqual(try Data(contentsOf: result), try Data(contentsOf: source))
    }
}
