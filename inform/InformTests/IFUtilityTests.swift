//
//  IFUtilityTests.swift
//  InformTests
//

import XCTest
import UniformTypeIdentifiers

final class IFUtilityTests: XCTestCase {

    func testContentTypesForKnownExtensions() {
        let types: [UTType] = IFUtility.contentTypes(forFilenameExtensions: ["txt", "rtf"])
        XCTAssertEqual(types.count, 2)
        XCTAssertTrue(types[0].conforms(to: .plainText))
        XCTAssertTrue(types[1].conforms(to: .rtf))
    }

    func testContentTypesForUnknownExtensionMatchTheExtension() {
        // An extension no app declares still gives a (dynamic) type, which panels match by extension
        let types: [UTType] = IFUtility.contentTypes(forFilenameExtensions: ["zoomSave"])
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types[0].preferredFilenameExtension?.lowercased(), "zoomsave")
    }

    func testContentTypesKeepOrder() {
        let extensions = ["rec", "txt", "zoomSave", "skein"]
        let types: [UTType] = IFUtility.contentTypes(forFilenameExtensions: extensions)
        XCTAssertEqual(types.count, extensions.count)
        XCTAssertTrue(types[1].conforms(to: .plainText))
    }

    func testContentTypesForNoExtensions() {
        XCTAssertEqual(IFUtility.contentTypes(forFilenameExtensions: [])?.count, 0)
    }

    // MARK: - Extension documentation pages

    private var materials: URL!

    override func setUpWithError() throws {
        materials = FileManager.default.temporaryDirectory
            .appendingPathComponent("IFUtilityTests-\(UUID().uuidString).materials")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: materials)
    }

    /// Makes Extensions/Reserved/Documentation/<author>/<folder>/index.html in the materials folder
    private func makePage(author: String, folder: String) throws -> String {
        let directory = materials.appendingPathComponent("Extensions/Reserved/Documentation")
            .appendingPathComponent(author).appendingPathComponent(folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let page = directory.appendingPathComponent("index.html")
        try Data("<html></html>".utf8).write(to: page)
        return page.path
    }

    private func pageFor(_ title: String, by author: String) -> String? {
        return IFUtility.documentationPage(forExtensionTitled: title, author: author, inMaterialsPath: materials.path)
    }

    func testFindsVersionedExtensionPage() throws {
        let page = try makePage(author: "Graham Nelson", folder: "English Language-v10_2_0")
        XCTAssertEqual(pageFor("English Language", by: "Graham Nelson"), page)
    }

    func testFindsUnversionedExtensionPage() throws {
        let page = try makePage(author: "Emily Short", folder: "Locksmith")
        XCTAssertEqual(pageFor("Locksmith", by: "Emily Short"), page)
    }

    func testPrefersLatestVersion() throws {
        _ = try makePage(author: "Emily Short", folder: "Locksmith-v9")
        let latest = try makePage(author: "Emily Short", folder: "Locksmith-v10")
        XCTAssertEqual(pageFor("Locksmith", by: "Emily Short"), latest)
    }

    func testIgnoresOtherExtensionsWithTheSamePrefix() throws {
        _ = try makePage(author: "Emily Short", folder: "Locksmith Extras-v1")
        _ = try makePage(author: "Emily Short", folder: "Locksmith-variant")
        XCTAssertNil(pageFor("Locksmith", by: "Emily Short"))
    }

    func testNoPageWhenNothingIsThere() {
        XCTAssertNil(pageFor("English Language", by: "Graham Nelson"))
    }

    // MARK: - Language versions

    /// Runs one of the app's tools, and returns what it prints
    private func output(of tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent(tool)
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        return printed
    }

    func testCoreBuildVersionIsTheVersionOfTheAppsCompiler() throws {
        let version: String = IFUtility.coreBuildVersion
        XCTAssertNotNil(version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression), version)
        XCTAssertTrue(IFUtility.path(forCompiler: "****").hasSuffix("/MacOS/ni"))

        let reported = try output(of: "ni", ["-version"])
        XCTAssertTrue(reported.hasPrefix("inform7 version \(version)"), reported)
    }

    func testGetInfoStringHasTheVersionsOfTheAppAndItsCompilers() throws {
        // Also recorded by the Skein as its generator
        let getInfo = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String)
        let appVersion = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let inform6 = try output(of: "inform6", ["-V"])
        let inform6Version = try XCTUnwrap(inform6.split(separator: " ").dropFirst().first, inform6)
        XCTAssertEqual(getInfo, "Inform version \(appVersion)/\(inform6Version)/\(IFUtility.coreBuildVersion!)")
    }

    func testLanguageVersion10_1UsesTheCurrentCompiler() {
        // The app has no retrospective build of 10.1 (TobyLobster/Inform#42)
        XCTAssertTrue(IFUtility.isLatestMajorMinorCompilerVersion("10.1"))
        XCTAssertEqual(IFUtility.path(forCompiler: "10.1"), IFUtility.path(forCompiler: "****"))
        XCTAssertEqual(IFUtility.path(forInformInternalAppSupport: "10.1"),
                       IFUtility.path(forInformInternalAppSupport: "****"))
        XCTAssertTrue(IFUtility.compilerVersion("10.1", isAfter: "6M62"))
    }

    func testOlderLanguageVersionsUseTheirOwnCompilers() {
        for version in ["6L02", "6L38", "6M62"] {
            XCTAssertTrue(IFUtility.path(forCompiler: version).hasSuffix("/MacOS/\(version)/ni"), version)
            XCTAssertTrue(IFUtility.path(forInformInternalAppSupport: version).hasSuffix("/retrospective/\(version)"), version)
        }
    }
}
