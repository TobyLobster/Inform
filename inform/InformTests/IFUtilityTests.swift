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
        XCTAssertEqual(IFUtility.contentTypes(forFilenameExtensions: []).count, 0)
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
        let version = try XCTUnwrap(IFUtility.coreBuildVersion)
        XCTAssertNotNil(version.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression), version)
        XCTAssertEqual(IFUtility.path(forCompiler: "****")?.hasSuffix("/MacOS/ni"), true)

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
            XCTAssertEqual(IFUtility.path(forCompiler: version)?.hasSuffix("/MacOS/\(version)/ni"), true, version)
            XCTAssertTrue(IFUtility.path(forInformInternalAppSupport: version).hasSuffix("/retrospective/\(version)"), version)
        }
    }

    /// The app's own compiler version, which has three parts (see above)
    private var current: String { return IFUtility.coreBuildVersion! }

    /// "" and "****" stand for the current version.
    func testFullCompilerVersion() {
        XCTAssertEqual(IFUtility.fullCompilerVersion(""), current)
        XCTAssertEqual(IFUtility.fullCompilerVersion("****"), current)
        XCTAssertEqual(IFUtility.fullCompilerVersion("6M62"), "6M62")
        XCTAssertEqual(IFUtility.fullCompilerVersion("10.1"), "10.1")
    }

    /// A version with three or more parts is cut to two, and anything else is left alone.
    func testMajorMinor() {
        XCTAssertEqual(IFUtility.majorMinor("10.2.0"), "10.2")
        XCTAssertEqual(IFUtility.majorMinor("1.2.3.4"), "1.2")
        XCTAssertEqual(IFUtility.majorMinor("10.1"), "10.1")
        XCTAssertEqual(IFUtility.majorMinor("6M62"), "6M62")
    }

    /// Only the current version, its major and minor version, and 10.1 use the current compiler.
    func testLatestMajorMinorCompilerVersion() {
        let parts = current.components(separatedBy: ".")
        XCTAssertTrue(IFUtility.isLatestMajorMinorCompilerVersion("****"))
        XCTAssertTrue(IFUtility.isLatestMajorMinorCompilerVersion(""))
        XCTAssertTrue(IFUtility.isLatestMajorMinorCompilerVersion(current))
        XCTAssertTrue(IFUtility.isLatestMajorMinorCompilerVersion("\(parts[0]).\(parts[1])"))
        XCTAssertFalse(IFUtility.isLatestMajorMinorCompilerVersion("\(parts[0]).\(parts[1]).99"))
        XCTAssertFalse(IFUtility.isLatestMajorMinorCompilerVersion("9.3"))
        XCTAssertFalse(IFUtility.isLatestMajorMinorCompilerVersion("6M62"))
    }

    /// Dotted versions are later than build codes like 6M62.
    func testComparesDottedVersionsWithBuildCodes() {
        XCTAssertEqual(IFUtility.compilerVersionCompare("10.1", other: "6M62"), .orderedDescending)
        XCTAssertEqual(IFUtility.compilerVersionCompare("6M62", other: "10.1"), .orderedAscending)
        XCTAssertEqual(IFUtility.compilerVersionCompare("****", other: "6M62"), .orderedDescending)
    }

    /// Dotted versions compare by number, ignoring trailing ".0"s.
    func testComparesDottedVersions() {
        XCTAssertEqual(IFUtility.compilerVersionCompare("9.3", other: "10.1"), .orderedAscending)
        XCTAssertEqual(IFUtility.compilerVersionCompare("10.1.10", other: "10.1.2"), .orderedDescending)
        XCTAssertEqual(IFUtility.compilerVersionCompare("10.1", other: "10.1.0"), .orderedSame)
        XCTAssertEqual(IFUtility.compilerVersionCompare("10.0", other: "10.0.0"), .orderedSame)
        XCTAssertEqual(IFUtility.compilerVersionCompare("", other: current), .orderedSame)
    }

    /// Build codes compare as text, ignoring case.
    func testComparesBuildCodes() {
        XCTAssertEqual(IFUtility.compilerVersionCompare("6L02", other: "6L38"), .orderedAscending)
        XCTAssertEqual(IFUtility.compilerVersionCompare("6M62", other: "6L38"), .orderedDescending)
        XCTAssertEqual(IFUtility.compilerVersionCompare("6m62", other: "6M62"), .orderedSame)
        XCTAssertEqual(IFUtility.compilerVersionCompare("5Z71", other: "6L02"), .orderedAscending)
    }

    func testCompilerVersionIsAfterAndNoLaterThan() {
        XCTAssertTrue(IFUtility.compilerVersion("****", isAfter: "6M62"))
        XCTAssertFalse(IFUtility.compilerVersion("6M62", isAfter: "6M62"))
        XCTAssertFalse(IFUtility.compilerVersion("6L38", isAfter: "6M62"))
        XCTAssertTrue(IFUtility.compilerVersion("6M62", isNoLaterThan: "6M62"))
        XCTAssertTrue(IFUtility.compilerVersion("6L38", isNoLaterThan: "6M62"))
        XCTAssertFalse(IFUtility.compilerVersion("10.1", isNoLaterThan: "6M62"))
    }

    /// Compilers up to 6L02 take -extension and -package, and later ones -format and -project.
    func testCompilerParameterNames() {
        for version in ["5Z71", "6L02"] {
            XCTAssertEqual(IFUtility.compilerFormatParameterName(version), "extension", version)
            XCTAssertEqual(IFUtility.compilerProjectParameterName(version), "package", version)
        }
        for version in ["6L38", "6M62", "10.1", "****"] {
            XCTAssertEqual(IFUtility.compilerFormatParameterName(version), "format", version)
            XCTAssertEqual(IFUtility.compilerProjectParameterName(version), "project", version)
        }
    }

    // MARK: - Paths
    //
    // Like the tests above, these expect the Advanced preferences not to use an external Inform
    // Core folder or a local copy of the Public Library, as tests mustn't change preferences.

    private var macOSFolder: String {
        return Bundle.main.executableURL!.deletingLastPathComponent().path
    }

    /// Inform's folder in the Library folder, which is in the tests' own home
    func testExternalPathsAreInInformsLibraryFolder() {
        let library = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]
        XCTAssertTrue(library.hasPrefix(NSHomeDirectory()), library)
        XCTAssertEqual(IFUtility.pathForInformExternalAppSupport(), library + "/Inform")
        XCTAssertEqual(IFUtility.pathForInformExternalExtensions(), library + "/Inform/Extensions")
        XCTAssertEqual(IFUtility.pathForInformExternalLibraries(), library + "/Inform/Libraries")
        XCTAssertEqual(IFUtility.pathForInformExternalDocumentation(), library + "/Inform/Documentation")
    }

    func testInternalPathsForTheCurrentVersion() {
        let internalFolder = Bundle.main.resourcePath! + "/Internal"
        for version in ["****", "", "10.1"] {
            XCTAssertEqual(IFUtility.path(forInformInternalAppSupport: version), internalFolder, version)
            XCTAssertEqual(IFUtility.path(forInformInternalExtensions: version), internalFolder + "/Extensions", version)
            XCTAssertEqual(IFUtility.path(forInformInternalLibraries: version), internalFolder + "/Libraries", version)
            XCTAssertEqual(IFUtility.path(forInformInternalDocumentation: version), internalFolder + "/Documentation", version)
        }
    }

    func testInternalPathsForOlderVersions() {
        let retrospective = Bundle.main.resourcePath! + "/retrospective/6M62"
        XCTAssertEqual(IFUtility.path(forInformInternalAppSupport: "6M62"), retrospective)
        XCTAssertEqual(IFUtility.path(forInformInternalExtensions: "6M62"), retrospective + "/Extensions")
        XCTAssertEqual(IFUtility.path(forInformInternalLibraries: "6M62"), retrospective + "/Libraries")
        XCTAssertEqual(IFUtility.path(forInformInternalDocumentation: "6M62"), retrospective + "/Documentation")
    }

    /// Without an external Inform Core folder, each tool is the app's own, whatever the version.
    func testExecutablesAreTheAppsOwn() {
        for tool in ["ni", "inbuild", "inform6", "cBlorb", "intest", "glulxe", "dumb-frotz"] {
            for version in ["****", "6M62"] {
                XCTAssertEqual(IFUtility.path(forInformExecutable: tool, version: version), macOSFolder + "/" + tool,
                               "\(tool) \(version)")
            }
        }
        XCTAssertNil(IFUtility.path(forInformExecutable: "NoSuchTool", version: "****"))
    }

    /// Versions up to 6M62 have their own ni, even one the app doesn't have.
    func testCompilerPaths() {
        XCTAssertEqual(IFUtility.path(forCompiler: "****"), macOSFolder + "/ni")
        XCTAssertEqual(IFUtility.path(forCompiler: "10.1"), macOSFolder + "/ni")
        XCTAssertEqual(IFUtility.path(forCompiler: "6L38"), macOSFolder + "/6L38/ni")
        XCTAssertEqual(IFUtility.path(forCompiler: "5Z71"), macOSFolder + "/5Z71/ni")
    }

    /// One new folder in the temporary folder, the same each time
    func testTemporaryDirectory() {
        let url = IFUtility.temporaryDirectoryURL()
        XCTAssertEqual(IFUtility.temporaryDirectoryURL(), url)
        XCTAssertEqual(url.deletingLastPathComponent().path, URL(fileURLWithPath: NSTemporaryDirectory()).path)
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testPublicLibraryURL() {
        XCTAssertEqual(IFUtility.publicLibraryURL(), URL(string: "https://ganelson.github.io/inform-public-library/v11/"))
    }

    /// A Debug build uses the address in ~/redirect_inform.txt instead, if there's one.
    func testDebugBuildsCanRedirectThePublicLibrary() throws {
        let redirect = (NSHomeDirectory() as NSString).appendingPathComponent("redirect_inform.txt")
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        try XCTSkipIf(FileManager.default.fileExists(atPath: redirect), "Leaves an existing redirect alone")

        try FileManager.default.createDirectory(atPath: NSHomeDirectory(), withIntermediateDirectories: true)
        try "  http://localhost:8000/index.html\n".write(toFile: redirect, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: redirect) }
        XCTAssertEqual(IFUtility.publicLibraryURL(), URL(string: "http://localhost:8000/index.html"))
    }

    // MARK: - URL schemes

    /// The file, test case and line number of a source: link, as strings
    private func source(_ link: String) -> [String]? {
        return IFUtility.decodeSourceSchemeURL(URL(string: link)!)?.map { "\($0)" }
    }

    /// The test case and node of a skein: link
    private func skein(_ link: String) -> [String]? {
        return IFUtility.decodeSkeinSchemeURL(URL(string: link)!)
    }

    func testDecodesSourceLinks() {
        XCTAssertEqual(source("source:story.ni#line10"), ["story.ni", "", "10"])
        XCTAssertEqual(source("source:story.ni#10"), ["story.ni", "", "10"])
        XCTAssertEqual(source("source:story.ni?case=A#line12"), ["story.ni", "A", "12"])
    }

    /// A link is percent-decoded before it's taken apart, so an encoded # still marks the line.
    func testDecodesPercentEncodedSourceLinks() {
        XCTAssertEqual(source("source:My%20Story.ni#line3"), ["My Story.ni", "", "3"])
        XCTAssertEqual(source("source:Caf%C3%A9.ni#line1"), ["Café.ni", "", "1"])
        XCTAssertEqual(source("source:Extensions/Emily%20Short/Locksmith.i7x%23line20"),
                       ["Extensions/Emily Short/Locksmith.i7x", "", "20"])
    }

    /// The web view reads the file and line from what it gets back, so a link without a line gives nothing.
    func testSourceLinkWithoutALineIsNotDecoded() {
        XCTAssertNil(source("source:story.ni"))
        XCTAssertNil(source("source:story.ni?case=A"))
    }

    /// A line that isn't a number, or "line" and a number, is line 0.
    func testSourceLinkWithAShortLineThatIsNotANumber() {
        XCTAssertEqual(source("source:story.ni#0"), ["story.ni", "", "0"])
        XCTAssertEqual(source("source:story.ni#ab"), ["story.ni", "", "0"])
        XCTAssertEqual(source("source:story.ni#line"), ["story.ni", "", "0"])
    }

    func testDecodesSkeinLinks() {
        XCTAssertEqual(skein("skein:1003?case=B"), ["B", "1003"])
        XCTAssertEqual(skein("skein:1003"), ["", "1003"])
        XCTAssertEqual(skein("SKEIN:1003#here"), ["", "1003"])
    }

    func testOnlyDecodesSkeinLinks() {
        XCTAssertNil(skein("source:1003?case=B"))
        XCTAssertNil(skein("1003"))
    }

    /// Parameters aren't separated at &, so a value runs to the next =.
    func testQueryParametersAreSplitOnlyAtEquals() {
        XCTAssertEqual(skein("skein:1003?case=B&x=1"), ["B&x", "1003"])
    }

    // MARK: - Localized strings

    func testLocalizedString() {
        XCTAssertEqual(IFUtility.localizedString("Index"), "Help")
        XCTAssertEqual(IFUtility.localizedString("Source Page Title"), "Source")
    }

    /// A key without a translation is its own translation.
    func testLocalizedStringWithoutATranslation() {
        XCTAssertEqual(IFUtility.localizedString("No such key"), "No such key")
    }

    func testLocalizedStringWithADefault() {
        XCTAssertEqual(IFUtility.localizedString("Index", default: "Fallback"), "Help")
        XCTAssertEqual(IFUtility.localizedString("No such key", default: "Fallback"), "Fallback")
        XCTAssertEqual(IFUtility.localizedString("No such key", default: nil), "No such key")
    }

    func testLocalizedStringFromATable() {
        XCTAssertEqual(IFUtility.localizedString("Debug log.txt", default: "Debug log", table: "CompilerOutput"), "Debugging")
        XCTAssertEqual(IFUtility.localizedString("Index", default: "Fallback", table: "CompilerOutput"), "Fallback")
        XCTAssertEqual(IFUtility.localizedString("Index", default: nil, table: nil), "Help")
    }

    // MARK: - Unescaping

    private func unescape(_ string: String) -> String {
        IFUtility.unescapeString(string)
    }

    func testUnescapeLeavesPlainTextAlone() {
        XCTAssertEqual(unescape(""), "")
        XCTAssertEqual(unescape("Hello, world"), "Hello, world")
        XCTAssertEqual(unescape("Café 😀"), "Café 😀")
    }

    func testUnescapesBackslashes() {
        XCTAssertEqual(unescape(#"a\nb\rc\td"#), "a\nb\rc\td")
        XCTAssertEqual(unescape(#"\"quoted\" \\ \q"#), #""quoted" \ q"#)
    }

    /// A backslash at the end has nothing to escape, so it stays.
    func testKeepsATrailingBackslash() {
        XCTAssertEqual(unescape(#"a\"#), #"a\"#)
    }

    /// The documentation writes characters as [=0x....=], since WebKit versions treat backslashes differently.
    func testUnescapesCharacterCodes() {
        XCTAssertEqual(unescape("say [=0x0022=]Hello[=0x0022=];[=0x000A=]"), "say \"Hello\";\n")
        XCTAssertEqual(unescape("[=0x00e9=][=0x00E9=]"), "éé")
        XCTAssertEqual(unescape("[=0x41=][=0x000000042=]"), "AB")
        XCTAssertEqual(unescape("[=BACK=]n"), #"\n"#)
    }

    /// Characters beyond 0xFFFF are written as surrogate pairs; a longer code keeps only its low 16 bits.
    func testCharacterCodesAreUTF16() {
        XCTAssertEqual(unescape("[=0xD83D=][=0xDE00=]"), "😀")
        XCTAssertEqual(unescape("[=0x1F600=]"), "\u{F600}")
    }

    /// A digit that isn't hexadecimal counts as 0.
    func testCharacterCodesWithBadDigits() {
        XCTAssertEqual(unescape("[=0x4G=]"), "@")
    }

    /// An escape runs to the next =], so an Inform comment starting [= is taken as one.
    func testUnknownEscapesAreQuestionMarks() {
        XCTAssertEqual(unescape("[=back=]"), "?")
        XCTAssertEqual(unescape("[=0X41=]"), "?")
        XCTAssertEqual(unescape("[==]"), "?")
        XCTAssertEqual(unescape("[=== Notes ===]"), "?")
    }

    /// Without a closing =] after it, [= is left as it is.
    func testLeavesAnUnclosedEscapeAlone() {
        XCTAssertEqual(unescape("[=0x41"), "[=0x41")
        XCTAssertEqual(unescape("a[="), "a[=")
        XCTAssertEqual(unescape("[=]"), "[=]")
    }

    func testLeavesOtherBracketsAlone() {
        XCTAssertEqual(unescape("[x] [ [=0x0041=]"), "[x] [ A")
        XCTAssertEqual(unescape("a["), "a[")
    }

    func testUnescapesLongStrings() {
        let long = String(repeating: #"ab[=0x0063=]\n"#, count: 200)
        XCTAssertEqual(unescape(long), String(repeating: "abc\n", count: 200))
    }

    // MARK: - Regular expressions

    func testFindsTheFirstMatch() throws {
        let text = "*** Run-time problem P10: Tried to divide by zero."
        let match = try XCTUnwrap(IFUtility.findMatch(#"^\*\*\* Run-time problem\s+([^\s:]+)(?::\s*(.*))?$"#, inText: text))
        XCTAssertEqual((text as NSString).substring(with: match.range(at: 1)), "P10")
        XCTAssertEqual((text as NSString).substring(with: match.range(at: 2)), "Tried to divide by zero.")
        XCTAssertEqual(IFUtility.findMatch(#"P\d+"#, inText: "P10 and P11")?.range, NSRange(location: 0, length: 3))
    }

    /// Ranges are in UTF-16 units, and the whole text is searched.
    func testMatchesAfterCharactersOutsideASCII() {
        XCTAssertEqual(IFUtility.findMatch(#"P\d+"#, inText: "😀 Café P10")?.range, NSRange(location: 8, length: 3))
    }

    func testNoMatch() {
        XCTAssertNil(IFUtility.findMatch(#"P\d+"#, inText: "Something else"))
        XCTAssertNil(IFUtility.findMatch(#"P\d+"#, inText: ""))
    }

    /// The options are the defaults: case matters, and ^ and $ are the ends of the whole text.
    func testMatchesWithDefaultOptions() {
        XCTAssertNil(IFUtility.findMatch("p10", inText: "P10"))
        XCTAssertNil(IFUtility.findMatch("^P10$", inText: "First line\nP10"))
    }

    /// A pattern that doesn't compile is logged and matches nothing.
    func testBadPatternMatchesNothing() {
        XCTAssertNil(IFUtility.findMatch("(unclosed", inText: "(unclosed"))
    }

    // MARK: - Unique IDs

    func testGeneratesIncreasingIDs() {
        let first = IFUtility.generateID()
        let second = IFUtility.generateID()
        XCTAssertGreaterThanOrEqual(first, 1000)
        XCTAssertGreaterThan(second, first)
    }

    /// IDs are unique even when they're made on several threads at once.
    func testGeneratesUniqueIDsOnAnyThread() {
        let lock = NSLock()
        var ids = Set<UInt>()
        DispatchQueue.concurrentPerform(iterations: 1000) { _ in
            let id = IFUtility.generateID()
            lock.lock()
            ids.insert(id)
            lock.unlock()
        }
        XCTAssertEqual(ids.count, 1000)
    }

    // MARK: - Unzipping

    /// Zips files with the given contents, from a folder in the materials folder
    private func makeZip(_ files: [String: String]) throws -> URL {
        let source = materials.appendingPathComponent("Zip source")
        for (path, contents) in files {
            let file = source.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: file)
        }
        let zip = materials.appendingPathComponent("Archive.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = source
        process.arguments = ["-q", "-r", zip.path, "."]
        try process.run()
        process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return zip
    }

    private func contents(_ url: URL) throws -> String {
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Unzips into the folder, making it, and leaves out what the Finder adds.
    func testUnzips() throws {
        let zip = try makeZip(["Story/story.ni": "\"Test\" by Me.",
                               "Story/.DS_Store": "",
                               "__MACOSX/Story/._story.ni": ""])
        let target = materials.appendingPathComponent("Unzipped/Here")
        XCTAssertTrue(IFUtility.unzip(zip, toDirectory: target))
        XCTAssertEqual(try contents(target.appendingPathComponent("Story/story.ni")), "\"Test\" by Me.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("Story/.DS_Store").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.appendingPathComponent("__MACOSX").path))
    }

    func testUnzipOverwritesFiles() throws {
        let zip = try makeZip(["story.ni": "New"])
        let target = materials.appendingPathComponent("Unzipped")
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try Data("Old".utf8).write(to: target.appendingPathComponent("story.ni"))
        XCTAssertTrue(IFUtility.unzip(zip, toDirectory: target))
        XCTAssertEqual(try contents(target.appendingPathComponent("story.ni")), "New")
    }

    func testUnzipFailsForAFileThatIsNotAZip() throws {
        try FileManager.default.createDirectory(at: materials, withIntermediateDirectories: true)
        let notZip = materials.appendingPathComponent("Not.zip")
        try Data("Not a zip".utf8).write(to: notZip)
        XCTAssertFalse(IFUtility.unzip(notZip, toDirectory: materials.appendingPathComponent("Unzipped")))
    }

    // MARK: - Sandboxing

    func testIsSandboxedWhenThereIsASandboxContainer() {
        XCTAssertEqual(IFUtility.isSandboxed, ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil)
    }

    // MARK: - Performing selectors

    private class Receiver: NSObject {
        var calls = 0
        @objc func ping() { calls += 1 }
    }

    func testPerformsASelectorTheObjectHas() {
        let receiver = Receiver()
        IFUtility.perform(#selector(Receiver.ping), object: receiver)
        XCTAssertEqual(receiver.calls, 1)
    }

    func testIgnoresASelectorTheObjectDoesNotHave() {
        let receiver = Receiver()
        IFUtility.perform(NSSelectorFromString("pong"), object: receiver)
        IFUtility.perform(#selector(Receiver.ping), object: nil)
        XCTAssertEqual(receiver.calls, 0)
    }

    // MARK: - Font sizes

    func testAdjustsTheFontSize() throws {
        for name in ["Helvetica", "Helvetica-Bold"] {
            let font = try XCTUnwrap(NSFont(name: name, size: 12))
            let adjusted = IFUtility.adjustAttributesFontSize([.font: font, .foregroundColor: NSColor.red], size: 20)
            let adjustedFont = try XCTUnwrap(adjusted[.font] as? NSFont)
            XCTAssertEqual(adjustedFont.fontName, name)
            XCTAssertEqual(adjustedFont.pointSize, 20)
            XCTAssertEqual(adjusted[.foregroundColor] as? NSColor, NSColor.red)
        }
    }

    /// Without a font, there's nothing to change.
    func testAdjustingTheFontSizeWithoutAFont() {
        let adjusted = IFUtility.adjustAttributesFontSize([.foregroundColor: NSColor.red], size: 20)
        XCTAssertNil(adjusted[.font])
        XCTAssertEqual(adjusted.count, 1)
    }

    // MARK: - Alerts

    /// An alert that records how it's shown, instead of showing it
    private final class AlertSpy: NSAlert {
        var ranModally = false
        var sheetWindow: NSWindow?

        override func runModal() -> NSApplication.ModalResponse {
            ranModally = true
            return .alertSecondButtonReturn
        }

        override func beginSheetModal(for sheetWindow: NSWindow,
                                      completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
            self.sheetWindow = sheetWindow
            handler?(.alertFirstButtonReturn)
        }
    }

    /// IFUtility as it is when the app isn't hosting the unit tests
    private final class AppUtility: IFUtility {
        override class var isHostingUnitTests: Bool {
            return false
        }
    }

    /// IFUtility, recording the alerts it's asked to show instead of showing them
    private final class AlertRecorder: IFUtility {
        static var shown: [(alert: NSAlert, window: NSWindow?)] = []

        override class func show(_ alert: NSAlert, for window: NSWindow?,
                                 completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {
            shown.append((alert, window))
        }
    }

    /// A window that's never on screen
    private func makeWindow() -> NSWindow {
        return NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled],
                        backing: .buffered, defer: true)
    }

    func testAnAlertWithAWindowIsASheetOnIt() {
        let window = makeWindow()
        let alert = AlertSpy()
        var responses: [NSApplication.ModalResponse] = []

        AppUtility.show(alert, for: window) { responses.append($0) }

        XCTAssertTrue(alert.sheetWindow === window)
        XCTAssertFalse(alert.ranModally)
        XCTAssertEqual(responses, [.alertFirstButtonReturn])
    }

    /// A sheet on no window doesn't appear, so an alert with no window is run modally
    func testAnAlertWithNoWindowIsRunModally() {
        let alert = AlertSpy()
        var responses: [NSApplication.ModalResponse] = []

        AppUtility.show(alert, for: nil) { responses.append($0) }

        XCTAssertTrue(alert.ranModally)
        XCTAssertNil(alert.sheetWindow)
        XCTAssertEqual(responses, [.alertSecondButtonReturn])
    }

    /// ...but not while the app is hosting the unit tests, as nobody would be there to close it
    func testAnAlertWithNoWindowIsntRunInTheUnitTests() {
        XCTAssertTrue(IFUtility.isHostingUnitTests)
        let alert = AlertSpy()
        var responses: [NSApplication.ModalResponse] = []

        IFUtility.show(alert, for: nil) { responses.append($0) }

        XCTAssertFalse(alert.ranModally)
        XCTAssertNil(alert.sheetWindow)
        XCTAssertEqual(responses, [.abort])
    }

    /// A warning is shown on the window it's given, or with none
    func testAWarningIsShownWithItsWindowOrNone() throws {
        AlertRecorder.shown = []
        defer { AlertRecorder.shown = [] }
        let window = makeWindow()

        AlertRecorder.runAlertWarning(window, localizedTitle: "On a window", informativeText: "Text")
        AlertRecorder.runAlertWarning(nil, localizedTitle: "On no window", informativeText: "Text")

        XCTAssertEqual(AlertRecorder.shown.map(\.alert.messageText), ["On a window", "On no window"])
        XCTAssertEqual(AlertRecorder.shown.map(\.alert.alertStyle), [.warning, .warning])
        let windows = AlertRecorder.shown.map(\.window)
        XCTAssertEqual(windows.count, 2)
        XCTAssertTrue(try XCTUnwrap(windows.first) === window)
        XCTAssertNil(try XCTUnwrap(windows.last))
    }
}
