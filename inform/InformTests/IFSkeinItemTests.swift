//
//  IFSkeinItemTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSkeinItemTests: XCTestCase {

    /// Dragging a knot copies it, and the knots below it, through the pasteboard as an archive.
    private func dragCopy(_ item: IFSkeinItem) throws -> IFSkeinItem {
        let type = NSPasteboard.PasteboardType(IFSkeinItemPboardType)
        let data = try XCTUnwrap(item.pasteboardPropertyList(forType: type) as? Data)
        return try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: IFSkeinItem.self, from: data))
    }

    func testDraggingKeepsTheWholeKnot() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        look.actual = "Library\n\n>"
        look.ideal = "The Library\n\n>"
        let jump: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "jump"))
        jump.actual = "You jump.\n\n>"
        jump.ideal = "You jump on the spot.\n\n>"
        jump.isTestSubItem = true

        let copy = try dragCopy(look)
        XCTAssertEqual(copy.command, "look")
        XCTAssertEqual(copy.actual, "Library\n\n>")
        XCTAssertEqual(copy.ideal, "The Library\n\n>")
        XCTAssertFalse(copy.isTestSubItem)
        XCTAssertNil(copy.parent)

        XCTAssertEqual(copy.children.count, 1)
        let copiedJump: IFSkeinItem = copy.children[0]
        XCTAssertTrue(copiedJump.parent === copy)
        XCTAssertEqual(copiedJump.command, "jump")
        XCTAssertEqual(copiedJump.actual, "You jump.\n\n>")
        XCTAssertEqual(copiedJump.ideal, "You jump on the spot.\n\n>")
        XCTAssertTrue(copiedJump.isTestSubItem)
    }

    /// A knot can be dragged, but not copied to other pasteboards.
    func testOnlyDragsAKnot() {
        let item = IFSkeinItem(skein: nil, command: "look")
        let type = NSPasteboard.PasteboardType(IFSkeinItemPboardType)
        XCTAssertEqual(item.writableTypes(for: NSPasteboard(name: .drag)), [type])
        XCTAssertEqual(item.writableTypes(for: .general), [])
        XCTAssertNil(item.pasteboardPropertyList(forType: .string))
    }

    // MARK: - Knots

    func testANewKnot() {
        let item = IFSkeinItem(skein: nil, command: "look")
        XCTAssertEqual(item.command, "look")
        XCTAssertEqual(item.actual, "")
        XCTAssertEqual(item.ideal, "")
        XCTAssertFalse(item.isTestSubItem)
        XCTAssertNil(item.parent)
        XCTAssertNil(item.skein)
        XCTAssertEqual(item.children.count, 0)
        XCTAssertTrue(item.commandSizeDidChange)
        XCTAssertNotEqual(item.uniqueId, IFSkeinItem(skein: nil, command: "look").uniqueId)
    }

    /// Commands have spaces for control characters, and no whitespace at the end. No text is empty.
    func testCommandsAndTranscriptsAreTidied() {
        XCTAssertEqual(IFSkeinItem(skein: nil, command: "go\tnorth\n").command, "go north")
        XCTAssertEqual(IFSkeinItem(skein: nil, command: "  look  ").command, "  look")
        XCTAssertEqual(IFSkeinItem(skein: nil, command: nil).command, "")

        let item = IFSkeinItem(skein: nil, command: "look")
        item.command = "say \u{7}hello\r\n"
        XCTAssertEqual(item.command, "say  hello")
        item.command = nil
        XCTAssertEqual(item.command, "")

        item.actual = "Library\n\n>"
        item.actual = nil
        XCTAssertEqual(item.actual, "")
        item.ideal = "Library\n\n>"
        item.ideal = nil
        XCTAssertEqual(item.ideal, "")
    }

    /// A knot's children are in order of their commands, with capital letters first.
    func testChildrenAreInOrderOfTheirCommands() {
        let skein: IFSkein = IFSkein(project: nil)
        for command in ["west", "east", "North", "north"] {
            skein.rootItem.addChild(IFSkeinItem(skein: skein, command: command))
        }
        XCTAssertEqual(skein.rootItem.children.map { $0.command }, ["North", "east", "north", "west"])
    }

    /// Adding a knot with the same command as a child merges the two, and the knots below them.
    func testAddingTheSameCommandMerges() {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        look.actual = "Library\n\n>"
        let north: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "north"))

        let lookAgain = IFSkeinItem(skein: skein, command: "look")
        lookAgain.ideal = "The Library\n\n>"
        let northAgain: IFSkeinItem = lookAgain.addChild(IFSkeinItem(skein: skein, command: "north"))
        let jump: IFSkeinItem = northAgain.addChild(IFSkeinItem(skein: skein, command: "jump"))
        let south: IFSkeinItem = lookAgain.addChild(IFSkeinItem(skein: skein, command: "south"))

        XCTAssertTrue(skein.rootItem.addChild(lookAgain) === look)
        XCTAssertEqual(skein.rootItem.children.count, 1)
        XCTAssertEqual(look.actual, "Library\n\n>")
        XCTAssertEqual(look.ideal, "The Library\n\n>")
        XCTAssertEqual(look.children.map { $0.command }, ["north", "south"])
        XCTAssertTrue(look.children[0] === north)
        XCTAssertTrue(south.parent === look)
        XCTAssertTrue(jump.parent === north)
        XCTAssertEqual(north.children.count, 1)

        // A knot for a command in a "test me" command is kept apart
        let testLook = IFSkeinItem(skein: skein, command: "look")
        testLook.isTestSubItem = true
        XCTAssertTrue(skein.rootItem.addChild(testLook) === testLook)
        XCTAssertEqual(skein.rootItem.children.count, 2)
        XCTAssertTrue(skein.rootItem.child(withCommand: "look", isTestSubItem: true) === testLook)
        XCTAssertTrue(skein.rootItem.child(withCommand: "look", isTestSubItem: false) === look)
        XCTAssertNil(skein.rootItem.child(withCommand: "west", isTestSubItem: false))
    }

    /// Adding a knot that's already in a skein moves it, with the knots below it.
    func testAddingAKnotMovesIt() {
        let first: IFSkein = IFSkein(project: nil)
        let second: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = first.rootItem.addChild(IFSkeinItem(skein: first, command: "look"))
        let north: IFSkeinItem = look.addChild(IFSkeinItem(skein: first, command: "north"))

        XCTAssertTrue(second.rootItem.addChild(look) === look)
        XCTAssertEqual(first.rootItem.children.count, 0)
        XCTAssertTrue(look.parent === second.rootItem)
        XCTAssertTrue(look.skein === second)
        XCTAssertTrue(north.skein === second)
    }

    /// A knot taken out of its skein keeps the knots below it, but they're no longer in the skein.
    func testRemovingAKnot() {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let north: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "north"))

        look.removeFromParent()
        XCTAssertEqual(skein.rootItem.children.count, 0)
        XCTAssertNil(look.parent)
        XCTAssertNil(look.skein)
        XCTAssertTrue(north.parent === look)
        XCTAssertNil(north.skein)

        look.removeFromParent()
        XCTAssertNil(look.parent)
    }

    func testFindingKnots() {
        let skein: IFSkein = IFSkein(project: nil)
        let root: IFSkeinItem = skein.rootItem
        let look: IFSkeinItem = root.addChild(IFSkeinItem(skein: skein, command: "look"))
        let north: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "north"))
        let south: IFSkeinItem = root.addChild(IFSkeinItem(skein: skein, command: "south"))

        XCTAssertTrue(north.root === root)
        XCTAssertTrue(root.root === root)

        XCTAssertTrue(root.hasDescendant(north))
        XCTAssertTrue(look.hasDescendant(look))
        XCTAssertFalse(look.hasDescendant(south))
        XCTAssertFalse(north.hasDescendant(look))
        XCTAssertFalse(look.hasDescendant(nil))

        XCTAssertTrue(root.find(withNodeId: north.uniqueId) === north)
        XCTAssertTrue(root.find(withNodeId: root.uniqueId) === root)
        XCTAssertNil(look.find(withNodeId: south.uniqueId))
    }

    /// A knot's children past any knots for the commands in a "test me" command.
    func testChildrenPastTestCommands() {
        let skein: IFSkein = IFSkein(project: nil)
        let test: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "test me"))
        XCTAssertNil(test.nonTestChildren)
        let look: IFSkeinItem = test.addChild(IFSkeinItem(skein: skein, command: "look"))
        look.isTestSubItem = true
        XCTAssertNil(test.nonTestChildren)
        look.addChild(IFSkeinItem(skein: skein, command: "south"))
        look.addChild(IFSkeinItem(skein: skein, command: "north"))
        XCTAssertEqual(test.nonTestChildren?.map { $0.command }, ["north", "south"])
        XCTAssertEqual(skein.rootItem.nonTestChildren?.map { $0.command }, ["test me"])
    }

    func testPrompts() {
        XCTAssertEqual(IFSkeinItem.prompt(for: "Library\n\n>"), ">")
        XCTAssertEqual(IFSkeinItem.prompt(for: "Library\n\nWhat now? "), "What now? ")
        XCTAssertEqual(IFSkeinItem.prompt(for: "Library"), "")
        XCTAssertEqual(IFSkeinItem.prompt(for: nil), "")
        XCTAssertEqual(IFSkeinItem.string(byRemovingPrompt: "Library\n\n>"), "Library\n")
        XCTAssertEqual(IFSkeinItem.string(byRemovingPrompt: "Library"), "Library")
        XCTAssertEqual(IFSkeinItem.string(byRemovingPrompt: nil), "")
    }

    func testTestCommands() {
        XCTAssertTrue(IFSkeinItem.isTestCommand("test me"))
        XCTAssertTrue(IFSkeinItem.isTestCommand("TEST ME"))
        XCTAssertFalse(IFSkeinItem.isTestCommand("test"))
        XCTAssertFalse(IFSkeinItem.isTestCommand("testing"))
        XCTAssertFalse(IFSkeinItem.isTestCommand(" test me"))
    }

    /// Changing a knot marks its skein as changed, but giving it what it already has doesn't.
    func testChangesMarkTheSkein() {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let changes: [(IFSkeinItem) -> Void] = [
            { $0.command = "examine" },
            { $0.actual = "Library\n\n>" },
            { $0.ideal = "The Library\n\n>" },
            { $0.isTestSubItem = true },
        ]
        for change in changes {
            skein.skeinChanged = false
            change(look)
            XCTAssertTrue(skein.skeinChanged)
            skein.skeinChanged = false
            change(look)
            XCTAssertFalse(skein.skeinChanged)
        }
    }

    /// Changing a command, or the font size, means a command's size has to be measured again.
    func testCommandSizeChanges() {
        let skein: IFSkein = IFSkein(project: nil)
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        let north: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "north"))
        look.commandSizeDidChange = false
        north.commandSizeDidChange = false

        look.command = "look"
        XCTAssertFalse(look.commandSizeDidChange)
        look.command = "examine"
        XCTAssertTrue(look.commandSizeDidChange)

        look.commandSizeDidChange = false
        look.forceCommandSizeChangeRecursively()
        XCTAssertTrue(look.commandSizeDidChange)
        XCTAssertTrue(north.commandSizeDidChange)
    }

    // MARK: - Differences

    func testDifferences() {
        let item = IFSkeinItem(skein: nil, command: "jump")
        item.actual = "You jump.\n\n>"
        XCTAssertFalse(item.hasIdeal)
        XCTAssertTrue(item.hasDifferences)
        XCTAssertFalse(item.hasBadge)

        item.ideal = "You jump.\n\n>"
        XCTAssertTrue(item.hasIdeal)
        XCTAssertFalse(item.hasDifferences)
        XCTAssertFalse(item.hasBadge)

        item.actual = "You jump on the spot.\n\n>"
        XCTAssertTrue(item.hasDifferences)
        XCTAssertTrue(item.hasBadge)
    }

    /// The transcripts are compared without a prompt they share, and without whitespace they share at either end.
    func testWhatIsCompared() {
        let item = IFSkeinItem(skein: nil, command: "jump")
        item.ideal = "\nYou jump.\n\n>"
        item.actual = "\nYou fall.\n\n>"
        XCTAssertEqual(item.differences.ideal, "You jump.")
        XCTAssertEqual(item.differences.actual, "You fall.")

        item.ideal = "You jump.\n\n>"
        item.actual = "You jump.\n\nWhat now?"
        XCTAssertEqual(item.differences.ideal, "You jump.\n\n>")
        XCTAssertEqual(item.differences.actual, "You jump.\n\nWhat now?")

        item.actual = "You jump.\n>"
        XCTAssertEqual(item.differences.ideal, "You jump.\n")
        XCTAssertEqual(item.differences.actual, "You jump.")
        XCTAssertTrue(item.hasDifferences)

        // With no transcript on one side, the other loses a standard prompt and the whitespace at either end
        item.ideal = ""
        item.actual = "\nYou jump.\n\n>"
        XCTAssertEqual(item.differences.ideal, "")
        XCTAssertEqual(item.differences.actual, "You jump.")
    }

    /// The report's state changes with the command and transcripts.
    func testReportState() {
        let a = IFSkeinItem(skein: nil, command: "jump")
        let b = IFSkeinItem(skein: nil, command: "jump")
        a.actual = "You jump.\n\n>"
        b.actual = "You jump.\n\n>"
        XCTAssertEqual(a.reportStateHash, b.reportStateHash)
        a.ideal = "You jump.\n\n>"
        XCTAssertNotEqual(a.reportStateHash, b.reportStateHash)
    }

    // MARK: - "test me" commands

    /// The transcript of a "test me" command, with "[1]", "[2]" and so on before each of its commands.
    private let testTranscript = "(Testing.)\n\n>[1] look\nLibrary\n\n>[2] jump\nYou jump.\n\n>"

    /// A "test me" command's transcript is split into a knot for each of its commands, and joined again.
    func testDecomposingATestCommand() throws {
        let skein: IFSkein = IFSkein(project: nil)
        let test: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "test me"))
        let last: IFSkeinItem = test.decomposeActual(testTranscript)
        XCTAssertEqual(test.actual, "(Testing.)\n\n>")
        XCTAssertEqual(test.children.count, 1)

        let look = try XCTUnwrap(test.children.first)
        XCTAssertEqual(look.command, "look")
        XCTAssertTrue(look.isTestSubItem)
        XCTAssertEqual(look.actual, "Library\n\n>")
        XCTAssertEqual(look.ideal, "")
        XCTAssertEqual(look.children.count, 1)

        XCTAssertTrue(look.children.first === last)
        XCTAssertEqual(last.command, "jump")
        XCTAssertTrue(last.isTestSubItem)
        XCTAssertEqual(last.actual, "You jump.\n\n>")
        XCTAssertTrue(last.skein === skein)
        XCTAssertEqual(test.composedActual, testTranscript)

        // Blessed transcripts are joined the same way, and kept when the command is played again
        test.ideal = "(Testing.)\n\n>"
        look.ideal = "Library\n\n>"
        last.ideal = "You jump.\n\n>"
        XCTAssertEqual(test.composedIdeal, testTranscript)
        let again = test.decomposeActual(testTranscript.replacingOccurrences(of: "You jump.", with: "You jump high."))
        XCTAssertTrue(again === last)
        XCTAssertTrue(test.children.first === look)
        XCTAssertEqual(last.actual, "You jump high.\n\n>")
        XCTAssertEqual(last.ideal, "You jump.\n\n>")
        XCTAssertTrue(last.hasBadge)
    }

    /// A knot's own transcripts can be split too, as when a skein is read.
    func testDecomposingAKnotsOwnTranscript() {
        let skein: IFSkein = IFSkein(project: nil)
        let test: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "test me"))
        test.actual = testTranscript
        test.ideal = testTranscript.replacingOccurrences(of: "You jump.", with: "You jump high.")
        let last: IFSkeinItem = test.decompose
        XCTAssertEqual(last.command, "jump")
        XCTAssertEqual(last.actual, "You jump.\n\n>")
        XCTAssertEqual(last.ideal, "You jump high.\n\n>")
        XCTAssertEqual(test.ideal, "(Testing.)\n\n>")
    }

    /// The knots below a "test me" command's knot go below the knot for its last command.
    func testDecomposingKeepsTheKnotsBelow() {
        let skein: IFSkein = IFSkein(project: nil)
        let test: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "test me"))
        let north: IFSkeinItem = test.addChild(IFSkeinItem(skein: skein, command: "north"))

        let last: IFSkeinItem = test.decomposeActual(testTranscript)
        XCTAssertEqual(test.children.map { $0.command }, ["look"])
        XCTAssertTrue(north.parent === last)
        XCTAssertTrue(last.children.first === north)
        XCTAssertTrue(north.skein === skein)

        // A different command makes a new branch in place of the old one
        let branch = test.decomposeActual("(Testing.)\n\n>[1] examine me\nAs good-looking as ever.\n\n>[2] jump\nYou jump.\n\n>")
        XCTAssertEqual(test.children.map { $0.command }, ["examine me"])
        XCTAssertEqual(branch.command, "jump")
        XCTAssertFalse(branch === last)
        XCTAssertTrue(north.parent === branch)
        XCTAssertTrue(branch.children.first === north)
        XCTAssertTrue(north.skein === skein)
    }

    /// A "test me" command with no commands in its transcript, or any other command, keeps its transcript.
    func testDecomposingWithoutTestCommands() {
        let skein: IFSkein = IFSkein(project: nil)
        let test: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "test me"))
        XCTAssertTrue(test.decomposeActual("Nothing to test.\n\n>") === test)
        XCTAssertEqual(test.actual, "Nothing to test.\n\n>")
        XCTAssertEqual(test.children.count, 0)

        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        look.ideal = "Library\n\n>"
        XCTAssertTrue(look.decomposeActual(testTranscript) === look)
        XCTAssertEqual(look.actual, testTranscript)
        XCTAssertEqual(look.ideal, "Library\n\n>")
        XCTAssertEqual(look.children.count, 0)
    }

    // MARK: - Undo

    /// Runs the body with a skein in a project that the document controller knows, so that changes to its knots can be undone.
    private func withUndo(_ body: (IFSkein, UndoManager) throws -> Void) throws {
        let project = IFProject()
        let skein = try XCTUnwrap(project.currentSkein)
        project.skeins.add(skein)
        let undoManager = try XCTUnwrap(project.undoManager)
        undoManager.groupsByEvent = false
        NSDocumentController.shared.addDocument(project)
        defer { NSDocumentController.shared.removeDocument(project) }
        try body(skein, undoManager)
    }

    /// Makes changes as one step to undo.
    private func change(_ undoManager: UndoManager, _ body: () -> Void) {
        undoManager.beginUndoGrouping()
        body()
        undoManager.endUndoGrouping()
    }

    func testUndoingChangesToAKnot() throws {
        try withUndo { skein, undoManager in
            var look: IFSkeinItem!
            change(undoManager) { look = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look")) }
            change(undoManager) { look.command = "examine" }
            change(undoManager) { look.actual = "Library\n\n>" }
            change(undoManager) { look.ideal = "The Library\n\n>" }
            change(undoManager) { look.isTestSubItem = true }

            undoManager.undo()
            XCTAssertFalse(look.isTestSubItem)
            undoManager.undo()
            XCTAssertEqual(look.ideal, "")
            undoManager.undo()
            XCTAssertEqual(look.actual, "")
            undoManager.undo()
            XCTAssertEqual(look.command, "look")
            undoManager.redo()
            XCTAssertEqual(look.command, "examine")
            undoManager.redo()
            XCTAssertEqual(look.actual, "Library\n\n>")
        }
    }

    func testUndoingAddingAndRemovingKnots() throws {
        try withUndo { skein, undoManager in
            var look: IFSkeinItem!
            var north: IFSkeinItem!
            change(undoManager) { look = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look")) }
            change(undoManager) { north = look.addChild(IFSkeinItem(skein: skein, command: "north")) }

            undoManager.undo()
            XCTAssertEqual(look.children.count, 0)
            XCTAssertNil(north.parent)
            XCTAssertNil(north.skein)
            undoManager.redo()
            XCTAssertTrue(look.children.first === north)
            XCTAssertTrue(north.parent === look)
            XCTAssertTrue(north.skein === skein)

            change(undoManager) { look.removeFromParent() }
            XCTAssertEqual(skein.rootItem.children.count, 0)
            undoManager.undo()
            XCTAssertTrue(skein.rootItem.children.first === look)
            XCTAssertTrue(look.parent === skein.rootItem)
            XCTAssertTrue(look.skein === skein)
            XCTAssertTrue(north.parent === look)
        }
    }

    /// Undoing the removal of a knot puts the knots below it back in the skein too.
    func testUndoingARemovalPutsTheKnotsBelowBack() throws {
        try withUndo { skein, undoManager in
            var look: IFSkeinItem!
            var north: IFSkeinItem!
            var jump: IFSkeinItem!
            change(undoManager) {
                look = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
                north = look.addChild(IFSkeinItem(skein: skein, command: "north"))
                jump = north.addChild(IFSkeinItem(skein: skein, command: "jump"))
            }
            change(undoManager) { look.removeFromParent() }
            undoManager.undo()
            XCTAssertTrue(look.skein === skein)
            XCTAssertTrue(north.skein === skein)
            XCTAssertTrue(jump.skein === skein)

            // So changes to them can be undone
            change(undoManager) { jump.command = "wave" }
            undoManager.undo()
            XCTAssertEqual(jump.command, "jump")
        }
    }
}
