//
//  IFNewInform7ExtensionProjectTests.swift
//  InformTests
//

import XCTest

final class IFNewInform7ExtensionProjectTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: folder)
    }

    /// A new, empty project file, which is only ever kept in memory
    private func projectFile() -> IFProjectFile {
        let file = IFProjectFile(emptyProject: ())
        file.filename = folder.appendingPathComponent("Lamplighter.i7xp").path
        return file
    }

    /// An installed extension, in the temporary folder
    private func installedExtension(_ contents: Data) throws -> URL {
        let url = folder.appendingPathComponent("Lamplighter.i7x")
        try contents.write(to: url)
        return url
    }

    /// The source files of a project file, by name
    private func sourceFiles(_ file: IFProjectFile) -> [String: Data] {
        return (file.sourceDirectory?.fileWrappers ?? [:]).compactMapValues { $0.regularFileContents }
    }

    // MARK: - The project type

    func testItsAnExtensionProjectWithNoOptions() {
        let type = IFNewInform7ExtensionProject()
        XCTAssertEqual(type.typeName, "org.inform-fiction.xproject")
        XCTAssertNil(type.configView)
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 0, length: 0))
    }

    // MARK: - The extension

    /// The project's extension is a copy of the extension given, byte for byte, with nothing selected
    func testAnExtensionGiven() throws {
        // Not UTF-8, to show that it's copied, not read as text
        var contents = Data("Lamplighter by Emily Short begins here.\n\nA lamp is a kind of thing.\n\n".utf8)
        contents.append(contentsOf: [0xC9, 0x0A, 0xFF, 0x0D, 0x0A])
        contents.append(Data("Lamplighter ends here.\n".utf8))
        let url = try installedExtension(contents)

        let type = IFNewInform7ExtensionProject()
        let file = projectFile()
        type.setupFile(file, from: nil, withStory: nil, withExtensionURL: url)

        XCTAssertEqual(sourceFiles(file), ["extension.i7x": contents])
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 0, length: 0))
        XCTAssertEqual(try Data(contentsOf: url), contents, "The extension given is left as it was")
    }

    /// With no extension given, as for New Extension, the project's extension is empty
    func testNoExtensionGiven() {
        let file = projectFile()
        IFNewInform7ExtensionProject().setupFile(file, from: nil, withStory: nil, withExtensionURL: nil)
        XCTAssertEqual(sourceFiles(file), ["extension.i7x": Data()])
    }

    /// An extension that can't be read, such as one removed since the menu was made, gives an empty extension too
    func testAnExtensionThatCantBeRead() {
        let file = projectFile()
        let missing = folder.appendingPathComponent("Missing.i7x")
        IFNewInform7ExtensionProject().setupFile(file, from: nil, withStory: nil, withExtensionURL: missing)
        XCTAssertEqual(sourceFiles(file), ["extension.i7x": Data()])

        let otherFile = projectFile()
        IFNewInform7ExtensionProject().setupFile(otherFile, from: nil, withStory: nil, withExtensionURL: folder)
        XCTAssertEqual(sourceFiles(otherFile), ["extension.i7x": Data()], "A folder can't be read as an extension")
    }

    /// A story given is ignored, as an extension project has no story.ni
    func testAStoryGivenIsIgnored() throws {
        let contents = Data("Lamplighter by Emily Short begins here.\n\nLamplighter ends here.\n".utf8)
        let url = try installedExtension(contents)

        let file = projectFile()
        IFNewInform7ExtensionProject().setupFile(file, from: nil, withStory: "The Lamp Room is a room.",
                                                 withExtensionURL: url)
        XCTAssertEqual(sourceFiles(file), ["extension.i7x": contents])

        let emptyFile = projectFile()
        IFNewInform7ExtensionProject().setupFile(emptyFile, from: nil, withStory: "The Lamp Room is a room.",
                                                 withExtensionURL: nil)
        XCTAssertEqual(sourceFiles(emptyFile), ["extension.i7x": Data()])
    }

    // MARK: - Settings

    /// A new extension project uses Inform 7, without the legacy extensions folder
    func testTheSettings() throws {
        let url = try installedExtension(Data("Lamplighter by Emily Short begins here.\n".utf8))
        for given in [url, nil] {
            let file = projectFile()
            IFNewInform7ExtensionProject().setupFile(file, from: nil, withStory: nil, withExtensionURL: given)

            let settings = try XCTUnwrap(file.settings)
            XCTAssertTrue(settings.usingNaturalInform)
            XCTAssertFalse(settings.allowLegacyExtensionDirectory)
        }
    }
}
