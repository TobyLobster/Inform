//
//  IFNewInform7ProjectTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFNewInform7ProjectTests.never-written")!
    }

    override func object(forKey defaultName: String) -> Any? {
        return values[defaultName]
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    override func removeObject(forKey defaultName: String) {
        values[defaultName] = nil
    }
}

final class IFNewInform7ProjectTests: XCTestCase {

    /// A project type whose preferences give the author's name
    private func projectType(author: String? = nil) -> IFNewInform7Project {
        var stored: [String: Any] = [:]
        if let author {
            stored["newGameAuthorName"] = author
        }
        let preferences = IFPreferences(userDefaults: MemoryDefaults([IFPreferencesDefault: stored]))
        return IFNewInform7Project(preferences: preferences)
    }

    /// A new, empty project file, which is only ever kept in memory
    private func projectFile(_ filename: String?) -> IFProjectFile {
        let file = IFProjectFile(emptyProject: ())
        file.filename = filename
        return file
    }

    /// The text of the project's story.ni
    private func story(_ file: IFProjectFile) -> String? {
        let wrapper = file.sourceDirectory?.fileWrappers?["story.ni"]
        return wrapper?.regularFileContents.map { String(decoding: $0, as: UTF8.self) }
    }

    /// Sets up a project file with the project type, with no story given
    private func setUp(_ file: IFProjectFile, with type: IFNewInform7Project) {
        type.setupFile(file, from: nil, withStory: nil, withExtensionURL: nil)
    }

    // MARK: - The project type

    func testItsAStoryProjectWithNoOptions() {
        let type = projectType()
        XCTAssertEqual(type.typeName, "org.inform-fiction.project")
        XCTAssertNil(type.configView)
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 0, length: 0))
    }

    // MARK: - A new story

    /// The story's title comes from the project's name, and its author from the preferences, with a room to start
    /// from, whose name is selected
    func testANewStory() {
        let type = projectType(author: "Emily Short")
        let file = projectFile("/Users/emily/Stories/Lamplighter.inform")
        setUp(file, with: type)

        let expected = "\"Lamplighter\" by Emily Short\n\nExample Location is a room. "
        XCTAssertEqual(story(file), expected)
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 30, length: 16))
        XCTAssertEqual((expected as NSString).substring(with: type.initialSelectionRange), "Example Location")
        XCTAssertEqual(file.sourceDirectory?.fileWrappers?.count, 1)
    }

    /// An author's name with a full stop in it is put in quotation marks, as Inform needs
    func testAnAuthorWithAFullStop() {
        let type = projectType(author: "J. R. Hartley")
        let file = projectFile("/Users/jr/Fly Fishing.inform")
        setUp(file, with: type)

        let expected = "\"Fly Fishing\" by \"J. R. Hartley\"\n\nExample Location is a room. "
        XCTAssertEqual(story(file), expected)
        XCTAssertEqual((expected as NSString).substring(with: type.initialSelectionRange), "Example Location")
    }

    /// With no author in the preferences, it's the user's name
    func testNoAuthorInThePreferences() {
        var userName = NSFullUserName()
        if userName.isEmpty { userName = NSUserName() }
        if userName.isEmpty { userName = "Unknown Author" }
        if userName.contains(".") { userName = "\"\(userName)\"" }

        let file = projectFile("/Users/emily/Lamplighter.inform")
        setUp(file, with: projectType())
        XCTAssertEqual(story(file), "\"Lamplighter\" by \(userName)\n\nExample Location is a room. ")
    }

    /// A project with no name gives a story called "Untitled"
    func testAProjectWithNoName() {
        let type = projectType(author: "Emily Short")
        let file = projectFile(nil)
        setUp(file, with: type)
        XCTAssertEqual(story(file), "\"Untitled\" by Emily Short\n\nExample Location is a room. ")
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 27, length: 16))
    }

    /// The story is written as UTF-8, and the room's name is selected in UTF-16 units, as a text view counts them
    func testANameThatIsntASCII() {
        let type = projectType(author: "Émilie Brontë")
        let file = projectFile("/Users/emilie/Le Dragon 🐉.inform")
        setUp(file, with: type)

        let expected = "\"Le Dragon 🐉\" by Émilie Brontë\n\nExample Location is a room. "
        XCTAssertEqual(file.sourceDirectory?.fileWrappers?["story.ni"]?.regularFileContents, Data(expected.utf8))
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 33, length: 16))
        XCTAssertEqual((expected as NSString).substring(with: type.initialSelectionRange), "Example Location")
    }

    // MARK: - A story given

    /// A story given, as from the documentation's examples, is the project's source as it is, with nothing selected
    func testAStoryGiven() {
        let type = projectType(author: "Emily Short")
        let file = projectFile("/Users/emily/Lamplighter.inform")
        let given = "\"Lamplighter\" by Graham Nelson\n\nThe Lamp Room is a room.\n"
        type.setupFile(file, from: nil, withStory: given, withExtensionURL: nil)

        XCTAssertEqual(story(file), given)
        XCTAssertEqual(type.initialSelectionRange, NSRange(location: 0, length: 0))
    }

    // MARK: - Settings

    /// A new project uses Inform 7, without the legacy extensions folder
    func testTheSettings() throws {
        for given in [nil, "The Lamp Room is a room."] {
            let file = projectFile("/Users/emily/Lamplighter.inform")
            projectType(author: "Emily Short").setupFile(file, from: nil, withStory: given, withExtensionURL: nil)

            let settings = try XCTUnwrap(file.settings)
            XCTAssertTrue(settings.usingNaturalInform)
            XCTAssertFalse(settings.allowLegacyExtensionDirectory)
        }
    }
}
