//
//  IFNewProjectTests.swift
//  InformTests
//

import XCTest

/// The New Project window's controller, whose window is loaded but never shown
private final class Controller: IFNewProject {
    override func showWindow(_ sender: Any?) {
        _ = window
    }
}

/// The New Extension window, as the app's New Extension menu item opens it for a project. New Project and
/// New Extension Project go straight to a save panel, and an extension that's created opens in a window that
/// saves its frame, so the tests stop short of those. While the app is hosting the tests, the alerts the window
/// would show, having no window to go on, are only logged, and end as if cancelled.
final class IFNewProjectTests: XCTestCase {
    private var folder: URL!
    /// The project the extension is for, which the window's project type only holds weakly
    private var project: IFProject!
    private var controller: Controller!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // Only the project's location is needed, so it isn't read from disk
        project = IFProject()
        project.fileURL = folder.appendingPathComponent("Lamplighter.inform")

        controller = Controller()
    }

    override func tearDownWithError() throws {
        controller.cancelButtonClicked(nil)
        controller = nil
        project.close()
        project = nil
        try FileManager.default.removeItem(at: folder)
    }

    /// Every text field in the view and the views inside it
    private func textFields(in view: NSView) -> [NSTextField] {
        let own = (view as? NSTextField).map { [$0] } ?? []
        return own + view.subviews.flatMap { textFields(in: $0) }
    }

    /// The text fields that can be typed in: the options' author and title, while they're shown
    private func editableFields() throws -> [NSTextField] {
        let contentView = try XCTUnwrap(controller.window?.contentView)
        return textFields(in: contentView).filter { $0.isEditable }
    }

    /// The options' two text fields, telling the title by the name it suggests
    private func optionsFields() throws -> (author: NSTextField, title: NSTextField) {
        let editable = try editableFields()
        XCTAssertEqual(editable.count, 2)
        let suggestedTitle = IFUtility.localizedString("New Extension")
        let title = try XCTUnwrap(editable.first { $0.stringValue == suggestedTitle })
        let author = try XCTUnwrap(editable.first { $0 !== title })
        return (author, title)
    }

    /// Opens the New Extension window and fills in its options
    private func newExtension(title: String, author: String) throws {
        controller.createInform7Extension(for: project)
        let fields = try optionsFields()

        // The window starts by editing the title; ending that means what's set here is what's read
        controller.window?.makeFirstResponder(nil)
        fields.title.stringValue = title
        fields.author.stringValue = author
    }

    /// Where the project keeps an extension with this title and author
    private func extensionURL(title: String, author: String) -> URL {
        return folder.appendingPathComponent("Lamplighter.materials/Extensions")
            .appendingPathComponent(author)
            .appendingPathComponent(title + ".i7x")
    }

    /// Answers yes to the question the window asked, as the alert would if it could be shown
    private func answerYes() {
        let selector = NSSelectorFromString("confirmDidEnd:returnCode:contextInfo:")
        XCTAssertTrue(controller.responds(to: selector))
        typealias Answer = @convention(c) (AnyObject, Selector, NSWindow?, Int, UnsafeMutableRawPointer?) -> Void
        let answer = unsafeBitCast(controller.method(for: selector), to: Answer.self)
        answer(controller, selector, nil, NSApplication.ModalResponse.alertFirstButtonReturn.rawValue, nil)
    }

    /// Writes an extension with this title and author into the project, and gives its text
    private func writeExtension(title: String, author: String) throws -> String {
        let url = extensionURL(title: title, author: author)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let text = "\(title) by \(author) begins here.\n\nA lamp is a kind of device.\n\n\(title) ends here.\n"
        try text.write(to: url, atomically: true, encoding: .utf8)
        return text
    }

    /// Everything in the test's folder, as paths inside it
    private func everythingInFolder() throws -> [String] {
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: folder.path))
        return (enumerator.allObjects as? [String] ?? []).sorted()
    }

    func testNewExtensionShowsItsOptions() throws {
        controller.createInform7Extension(for: project)

        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.title, IFUtility.localizedString("Create Extension"))
        let contentView = try XCTUnwrap(window.contentView)
        XCTAssertTrue(textFields(in: contentView).contains { !$0.isEditable && $0.stringValue == IFUtility.localizedString("Create Extension") })

        // The title is suggested, and typing goes into it
        let fields = try optionsFields()
        XCTAssertEqual(fields.title.stringValue, IFUtility.localizedString("New Extension"))
        let firstResponder = window.firstResponder
        XCTAssertTrue(firstResponder === fields.title || (firstResponder as? NSText)?.delegate === fields.title)
    }

    func testCancelTakesAwayTheOptions() throws {
        controller.createInform7Extension(for: project)
        XCTAssertEqual(try editableFields().count, 2)

        controller.cancelButtonClicked(nil)

        XCTAssertEqual(try editableFields().count, 0)
        XCTAssertFalse(try XCTUnwrap(controller.window).isVisible)
    }

    func testNewExtensionAgainShowsOneSetOfOptions() throws {
        controller.createInform7Extension(for: project)
        controller.createInform7Extension(for: project)

        XCTAssertEqual(try editableFields().count, 2)
    }

    func testCreateWithNoTitleWritesNothing() throws {
        try newExtension(title: "", author: "Emily Short")

        controller.okButtonClicked(nil)

        // The error is shown, and the options stay for the title to be put in
        XCTAssertEqual(try everythingInFolder(), [])
        XCTAssertEqual(try editableFields().count, 2)
    }

    func testCreateWithNoAuthorWritesNothing() throws {
        try newExtension(title: "Lamps", author: "")

        controller.okButtonClicked(nil)

        XCTAssertEqual(try everythingInFolder(), [])
        XCTAssertEqual(try editableFields().count, 2)
    }

    func testCreateForAProjectNeverSavedWritesNothing() throws {
        try newExtension(title: "Lamps", author: "Emily Short")
        project.fileURL = nil

        controller.okButtonClicked(nil)

        XCTAssertEqual(try everythingInFolder(), [])
        XCTAssertEqual(try editableFields().count, 2)
    }

    func testCreateOverAnExtensionAsksFirst() throws {
        let oldText = try writeExtension(title: "Lamps", author: "Emily Short")
        try newExtension(title: "Lamps", author: "Emily Short")

        controller.okButtonClicked(nil)

        // Asked, and not answered yes, so the extension is as it was, and the options stay
        let existing = extensionURL(title: "Lamps", author: "Emily Short")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), oldText)
        XCTAssertEqual(try editableFields().count, 2)
    }

    func testCreateOverAnExtensionAfterTheProjectHasGoneWritesNothing() throws {
        let oldText = try writeExtension(title: "Lamps", author: "Emily Short")
        try newExtension(title: "Lamps", author: "Emily Short")
        controller.okButtonClicked(nil)

        // The project goes while the window asks, as when it's closed
        project.fileURL = nil
        answerYes()

        // The error is shown, and the options stay
        let existing = extensionURL(title: "Lamps", author: "Emily Short")
        XCTAssertEqual(try String(contentsOf: existing, encoding: .utf8), oldText)
        XCTAssertEqual(try editableFields().count, 2)
    }
}
