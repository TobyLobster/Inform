//
//  IFSingleControllerTests.swift
//  InformTests
//

import XCTest

/// The window of a file opened on its own. Each window is loaded, but never shown.
final class IFSingleControllerTests: XCTestCase {

    /// The controller, keeping its window's frame out of the preferences: it notes the frame autosave name it's
    /// given, and doesn't pass it on to the window.
    private final class Controller: IFSingleController {
        var autosaveNames: [String] = []

        override var windowFrameAutosaveName: NSWindow.FrameAutosaveName {
            get { return "" }
            set { autosaveNames.append(newValue) }
        }
    }

    private let save = Selector(("saveDocument:"))
    private let shiftLeft = Selector(("shiftLeft:"))
    private let shiftRight = Selector(("shiftRight:"))
    private let renumberSections = Selector(("renumberSections:"))
    private let commentOutSelection = Selector(("commentOutSelection:"))
    private let uncommentSelection = Selector(("uncommentSelection:"))

    /// Where the files would be: nothing is written there
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent("IFSingleControllerTests").path

    /// The document type the app gives a file, by its extension
    private func typeName(_ name: String) -> String {
        switch (name as NSString).pathExtension.lowercased() {
        case "inf": return "Inform 6 source file"
        case "h": return "public.c-header"
        case "i7x", "": return "org.inform-fiction.inform7.extension"
        default: return "Inform 7 source file"
        }
    }

    /// A document with this text, for a file of this name
    private func document(_ text: String, name: String, in folder: String? = nil) throws -> IFSingleFile {
        let file = IFSingleFile()
        try file.read(from: Data(text.utf8), ofType: typeName(name))
        file.fileURL = URL(fileURLWithPath: (folder ?? self.folder) + "/" + name)
        return file
    }

    /// The document's window, loaded by a new controller, and the view of its text
    private func open(_ file: IFSingleFile,
                      selecting range: NSRange = NSRange(location: 0, length: 0)) throws -> (Controller, NSWindow, NSTextView) {
        let controller = Controller(initialSelectionRange: range)
        file.addWindowController(controller)
        addTeardownBlock {
            controller.close()
            file.removeWindowController(controller)
        }

        let window = try XCTUnwrap(controller.window)
        let textView = try XCTUnwrap(window.initialFirstResponder as? NSTextView)
        return (controller, window, textView)
    }

    private func item(_ action: Selector) -> NSMenuItem {
        return NSMenuItem(title: "", action: action, keyEquivalent: "")
    }

    // MARK: - The window

    func testTheWindowShowsTheFile() throws {
        let file = try document("Lamps by Emily Short begins here.\n", name: "Lamps.i7x")
        let (controller, window, textView) = try open(file, selecting: NSRange(location: 6, length: 2))

        XCTAssertTrue(textView.textStorage === file.storage)
        XCTAssertTrue(textView.isEditable)
        XCTAssertFalse(textView.isRichText)
        XCTAssertEqual(textView.enabledTextCheckingTypes, 0)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 2))
        XCTAssertEqual(textView.isContinuousSpellCheckingEnabled,
                       try XCTUnwrap(NSApp.delegate as? IFAppDelegate).sourceSpellChecking)
        XCTAssertEqual(controller.autosaveNames.last, "SingleFile")
        XCTAssertFalse(window.isVisible)
    }

    /// The extensions built into the app can't be edited or saved
    func testAReadOnlyFile() throws {
        let appExtensions = IFUtility.path(forInformInternalExtensions: "")
        let file = try document("Basic Inform by Graham Nelson begins here.\n", name: "Basic Inform.i7x",
                                in: appExtensions + "/Graham Nelson")
        let (controller, _, textView) = try open(file)
        XCTAssertFalse(textView.isEditable)
        XCTAssertFalse(controller.validateMenuItem(item(save)))

        let (writable, _, _) = try open(try document("Lamps by Emily Short begins here.\n", name: "Lamps.i7x"))
        XCTAssertTrue(writable.validateMenuItem(item(save)))
    }

    /// Extensions have the extension paper's colour, and other files the source paper's
    func testTheBackgroundColour() throws {
        for name in ["Lamps.i7x", "Lamps.h", "Lamps"] {
            let (_, _, textView) = try open(try document("", name: name))
            XCTAssertEqual(textView.backgroundColor, IFPreferences.shared.extensionPaper.colour, name)
        }
        for name in ["Lamps.ni", "Lamps.i7", "Lamps.inf"] {
            let (_, _, textView) = try open(try document("", name: name))
            XCTAssertEqual(textView.backgroundColor, IFPreferences.shared.sourcePaper.colour, name)
        }
    }

    func testChangingTheEditingPreferencesSetsTheBackgroundAgain() throws {
        let (_, _, textView) = try open(try document("", name: "Lamps.ni"))
        textView.backgroundColor = NSColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)

        NotificationCenter.default.post(name: .IFPreferencesEditingDidChange,
                                        object: IFPreferences.shared)
        XCTAssertEqual(textView.backgroundColor, IFPreferences.shared.sourcePaper.colour)
    }

    func testSpellChecking() throws {
        let (controller, _, textView) = try open(try document("", name: "Lamps.ni"))
        controller.setSourceSpellChecking(true)
        XCTAssertTrue(textView.isContinuousSpellCheckingEnabled)
        controller.setSourceSpellChecking(false)
        XCTAssertFalse(textView.isContinuousSpellCheckingEnabled)
    }

    // MARK: - The source commands

    /// The source commands need the text to have the focus; other commands are left alone
    func testTheSourceCommandsNeedTheText() throws {
        let file = try document("Section 1 - Lamps\n\nThe lamp is a thing.\n", name: "Lamps.ni")
        let (controller, window, textView) = try open(file, selecting: NSRange(location: 0, length: 7))
        let commands = [shiftLeft, shiftRight, renumberSections, commentOutSelection, uncommentSelection]

        window.makeFirstResponder(nil)
        for command in commands {
            XCTAssertFalse(controller.validateMenuItem(item(command)), "\(command)")
        }
        XCTAssertTrue(controller.validateMenuItem(item(#selector(NSWindow.performClose(_:)))))

        XCTAssertTrue(window.makeFirstResponder(textView))
        for command in commands {
            XCTAssertTrue(controller.validateMenuItem(item(command)), "\(command)")
        }
    }

    /// Only Inform 7 can be commented out or uncommented, and only when some of it is selected
    func testCommentingNeedsInform7AndASelection() throws {
        for name in ["Lamps.inf", "Lamps.h"] {
            let (controller, window, textView) = try open(try document("! Lamps\n", name: name),
                                                          selecting: NSRange(location: 0, length: 3))
            window.makeFirstResponder(textView)
            XCTAssertFalse(controller.validateMenuItem(item(commentOutSelection)), name)
            XCTAssertFalse(controller.validateMenuItem(item(uncommentSelection)), name)
            XCTAssertTrue(controller.validateMenuItem(item(shiftLeft)), name)
        }

        for name in ["Lamps.ni", "Lamps.i7", "Lamps.i7x", "Lamps"] {
            let (controller, window, textView) = try open(try document("The lamp is a thing.\n", name: name))
            window.makeFirstResponder(textView)
            XCTAssertFalse(controller.validateMenuItem(item(commentOutSelection)), name)
            XCTAssertFalse(controller.validateMenuItem(item(uncommentSelection)), name)

            textView.setSelectedRange(NSRange(location: 4, length: 4))
            XCTAssertTrue(controller.validateMenuItem(item(commentOutSelection)), name)
            XCTAssertTrue(controller.validateMenuItem(item(uncommentSelection)), name)
        }
    }

    /// Only text with intelligence, which finds its headings, can have its sections renumbered
    func testRenumberingNeedsIntelligence() throws {
        for name in ["Lamps.inf", "Lamps.h"] {
            let (controller, window, textView) = try open(try document("! Lamps\n", name: name))
            window.makeFirstResponder(textView)
            XCTAssertFalse(controller.validateMenuItem(item(renumberSections)), name)
        }
        for name in ["Lamps.ni", "Lamps.i7x"] {
            let (controller, window, textView) = try open(try document("Section 1 - Lamps\n", name: name))
            window.makeFirstResponder(textView)
            XCTAssertTrue(controller.validateMenuItem(item(renumberSections)), name)
        }
    }

    /// The commands act on the text with the focus, and do nothing without it
    func testTheSourceCommands() throws {
        let file = try document("a\nb\n", name: "Lamps.ni")
        let (controller, window, textView) = try open(file, selecting: NSRange(location: 0, length: 3))

        window.makeFirstResponder(nil)
        for command in [shiftLeft, shiftRight, renumberSections, commentOutSelection, uncommentSelection] {
            controller.perform(command, with: nil)
        }
        XCTAssertEqual(file.storage.string, "a\nb\n")

        window.makeFirstResponder(textView)
        controller.perform(shiftRight, with: nil)
        XCTAssertEqual(file.storage.string, "\ta\n\tb\n")
        controller.perform(shiftLeft, with: nil)
        XCTAssertEqual(file.storage.string, "a\nb\n")

        textView.setSelectedRange(NSRange(location: 0, length: 1))
        controller.perform(commentOutSelection, with: nil)
        XCTAssertEqual(file.storage.string, "[a]\nb\n")
        controller.perform(uncommentSelection, with: nil)
        XCTAssertEqual(file.storage.string, "a\nb\n")
    }

    func testRenumberingSections() throws {
        let file = try document("Section 1 - A\n\nSection 3 - B\n", name: "Book.ni")
        let (controller, window, textView) = try open(file)
        window.makeFirstResponder(textView)
        controller.perform(renumberSections, with: nil)
        XCTAssertEqual(file.storage.string, "Section 1 - A\n\nSection 2 - B\n")
    }

    // MARK: - Showing a line or a range

    /// The project controller asks for a line, numbered from 1, and it's selected without its line break
    func testHighlightingALine() throws {
        let file = try document("First\nSecond line\nThird\n", name: "Lamps.ni")
        let (controller, _, textView) = try open(file)
        let path = try XCTUnwrap(file.fileURL).path

        controller.highlightSourceFileLine(2, inFile: path, style: .neutral)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 11))
        controller.highlightSourceFileLine(1, inFile: path, style: .error)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 5))

        // The empty line after the last line break
        controller.highlightSourceFileLine(4, inFile: path, style: .neutral)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 24, length: 0))
    }

    /// Find in Files shows a match by selecting it
    func testIndicatingARange() throws {
        let (controller, _, textView) = try open(try document("The lamp is a thing.\n", name: "Lamps.ni"))
        controller.indicateRange(NSRange(location: 4, length: 4))
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 4, length: 4))
    }
}
