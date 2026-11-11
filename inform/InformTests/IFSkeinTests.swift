//
//  IFSkeinTests.swift
//  InformTests
//

import XCTest

@MainActor
final class IFSkeinTests: XCTestCase {

    /// Records the skein's change notifications.
    private final class Observer: NSObject {
        var changes: [String] = []

        init(_ skein: IFSkein) {
            super.init()
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(skeinChanged(_:)),
                                                   name: .IFSkeinChanged,
                                                   object: skein)
        }

        func stop() {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func skeinChanged(_ notification: Notification) {
            let animate = notification.userInfo?[IFSkeinChangedAnimateKey] as? Bool
            let keepActiveVisible = notification.userInfo?[IFSkeinKeepActiveVisibleKey] as? Bool
            changes.append("animate \(animate.map(String.init) ?? "-"), keep visible \(keepActiveVisible.map(String.init) ?? "-")")
        }
    }

    func testANewSkein() {
        let skein: IFSkein = IFSkein(project: nil)
        XCTAssertEqual(skein.rootItem.command, "- start -")
        XCTAssertTrue(skein.rootItem.skein === skein)
        XCTAssertEqual(skein.rootItem.children.count, 0)
        XCTAssertNil(skein.activeItem)
        XCTAssertNil(skein.winningItem)
        XCTAssertNil(skein.draggingItem)
        XCTAssertFalse(skein.draggingSourceNeedsUpdating)
        XCTAssertTrue(skein.skeinChanged)
        XCTAssertEqual(skein.previousCommands.count, 0)
    }

    // MARK: - Playing

    /// Each command goes into a knot below the active one, and the game's output into the active knot.
    func testPlayingAddsKnots() throws {
        let skein: IFSkein = IFSkein(project: nil)
        skein.interpreterRestart()
        XCTAssertTrue(skein.activeItem === skein.rootItem)
        skein.outputText("Library\n")
        skein.outputText("\n>")
        skein.waitingForInput()
        XCTAssertEqual(skein.rootItem.actual, "Library\n\n>")

        skein.inputCommand("look")
        let look = try XCTUnwrap(skein.activeItem)
        XCTAssertEqual(look.command, "look")
        XCTAssertTrue(look.parent === skein.rootItem)
        XCTAssertEqual(look.actual, "")
        skein.waitingForInput()
        XCTAssertEqual(look.actual, "", "No output, so nothing changes")
        skein.outputText("Library\n\n>")
        skein.waitingForInput()
        XCTAssertEqual(look.actual, "Library\n\n>")

        skein.inputCommand("jump")
        XCTAssertEqual(skein.previousCommands as? [String], ["jump", "look"])

        // Playing the same command again goes through the same knot
        skein.interpreterRestart()
        XCTAssertEqual(skein.previousCommands.count, 0)
        XCTAssertTrue(skein.activeItem === skein.rootItem)
        skein.inputCommand("look")
        XCTAssertTrue(skein.activeItem === look)

        skein.interpreterStop()
        XCTAssertNil(skein.activeItem)
    }

    /// Output still waiting for the active knot is given to it when the game restarts.
    func testRestartingKeepsTheLastOutput() throws {
        let skein: IFSkein = IFSkein(project: nil)
        skein.interpreterRestart()
        skein.inputCommand("restart")
        let restart = try XCTUnwrap(skein.activeItem)
        skein.outputText("Are you sure?")
        skein.interpreterRestart()
        XCTAssertEqual(restart.actual, "Are you sure?")
        XCTAssertTrue(skein.activeItem === skein.rootItem)
    }

    /// A "test me" command's output is split into a knot for each of its commands.
    func testPlayingATestCommand() throws {
        let skein: IFSkein = IFSkein(project: nil)
        skein.interpreterRestart()
        skein.inputCommand("test me")
        let test = try XCTUnwrap(skein.activeItem)
        skein.outputText("(Testing.)\n\n>[1] look\nLibrary\n\n>")
        skein.waitingForInput()
        XCTAssertEqual(test.actual, "(Testing.)\n\n>")
        XCTAssertEqual(skein.activeItem?.command, "look")
        XCTAssertTrue(skein.activeItem?.isTestSubItem ?? false)
        XCTAssertTrue(skein.activeItem?.parent === test)
    }

    /// The skein is marked as changed only when playing changes it.
    func testPlayingMarksChanges() {
        let skein: IFSkein = IFSkein(project: nil)
        skein.interpreterRestart()
        skein.inputCommand("look")
        XCTAssertTrue(skein.skeinChanged)
        skein.outputText("Library\n\n>")
        skein.waitingForInput()
        XCTAssertTrue(skein.skeinChanged)

        skein.interpreterRestart()
        skein.inputCommand("look")
        XCTAssertFalse(skein.skeinChanged)
        skein.outputText("Library\n\n>")
        skein.waitingForInput()
        XCTAssertFalse(skein.skeinChanged)
    }

    /// Playing marks the project as edited, but only if it changes the skein.
    func testPlayingMarksTheProjectAsEdited() throws {
        let project = IFProject()
        let skein = try XCTUnwrap(project.currentSkein)
        skein.interpreterRestart()
        skein.inputCommand("look")
        XCTAssertTrue(project.isDocumentEdited)

        project.updateChangeCount(.changeCleared)
        skein.interpreterRestart()
        skein.inputCommand("look")
        XCTAssertFalse(project.isDocumentEdited)
        skein.outputText("Library\n\n>")
        skein.waitingForInput()
        XCTAssertTrue(project.isDocumentEdited)
    }

    func testPlayingTellsObservers() {
        let skein: IFSkein = IFSkein(project: nil)
        let observer = Observer(skein)
        defer { observer.stop() }

        skein.interpreterRestart()
        skein.inputCommand("look")
        skein.waitingForInput()
        skein.outputText("Library\n\n>")
        skein.waitingForInput()
        skein.interpreterStop()
        skein.postChanged(withAnimate: true, keepActiveVisible: false)
        XCTAssertEqual(observer.changes, ["animate false, keep visible false",
                                          "animate false, keep visible false",
                                          "animate false, keep visible true",
                                          "animate false, keep visible false",
                                          "animate true, keep visible false"])
    }

    /// Keys are typed as their ZSCII codes.
    func testTypingKeys() {
        let skein: IFSkein = IFSkein(project: nil)
        skein.interpreterRestart()
        func typeKey(_ key: Int, _ rest: String = "") -> String? {
            skein.inputCharacter(String(Character(Unicode.Scalar(UInt32(key))!)) + rest)
            return skein.previousCommands[0] as? String
        }
        XCTAssertEqual(typeKey(NSUpArrowFunctionKey), "\u{81}")
        XCTAssertEqual(typeKey(NSDownArrowFunctionKey), "\u{82}")
        XCTAssertEqual(typeKey(NSLeftArrowFunctionKey), "\u{83}")
        XCTAssertEqual(typeKey(NSRightArrowFunctionKey), "\u{84}")
        XCTAssertEqual(typeKey(NSDeleteFunctionKey), "\u{8}")
        XCTAssertEqual(typeKey(NSF1FunctionKey), "\u{85}")
        XCTAssertEqual(typeKey(NSF12FunctionKey), "\u{90}")
        XCTAssertEqual(typeKey(NSF33FunctionKey), "\u{FC}")
        XCTAssertEqual(typeKey(NSF34FunctionKey), "\u{FE}")
        XCTAssertEqual(typeKey(NSF35FunctionKey), "\u{FD}")
        let f13 = String(Character(Unicode.Scalar(UInt32(NSF13FunctionKey))!))
        XCTAssertEqual(typeKey(NSF13FunctionKey), f13, "Other keys are typed as they are")
        XCTAssertEqual(typeKey(NSUpArrowFunctionKey, "x"), "\u{81}x")
        skein.inputCharacter("y")
        XCTAssertEqual(skein.previousCommands[0] as? String, "y")
        XCTAssertEqual(skein.activeItem?.command, "y")
    }

    // MARK: - Reports

    /// A skein with these knots, and its knots by command.
    private func skeinWithKnots() -> (IFSkein, [String: IFSkeinItem]) {
        let skein: IFSkein = IFSkein(project: nil)
        skein.rootItem.actual = "Library\n\n>"
        let look: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "look"))
        look.actual = "The Library\n\n>"
        let inventory: IFSkeinItem = look.addChild(IFSkeinItem(skein: skein, command: "inventory"))
        inventory.actual = "You are carrying nothing.\n\n>"
        let jump: IFSkeinItem = skein.rootItem.addChild(IFSkeinItem(skein: skein, command: "jump"))
        jump.actual = "You jump.\n\n>"
        return (skein, ["look": look, "inventory": inventory, "jump": jump])
    }

    func testTranscript() {
        let (skein, items) = skeinWithKnots()
        XCTAssertEqual(skein.transcript(toPoint: items["inventory"]),
                       "Library\n\n>look\nThe Library\n\n>inventory\nYou are carrying nothing.\n\n>")
        XCTAssertEqual(skein.transcript(toPoint: skein.rootItem), "Library\n\n>")
        XCTAssertEqual(skein.transcript(toPoint: nil), "", "With no active knot")
        skein.activeItem = items["jump"]
        XCTAssertEqual(skein.transcript(toPoint: nil), "Library\n\n>jump\nYou jump.\n\n>")
    }

    /// The knot to report is the first one with differences on the way to the active knot, or else the active knot.
    func testNodeToReport() throws {
        let (skein, items) = skeinWithKnots()
        let look = try XCTUnwrap(items["look"])
        let inventory = try XCTUnwrap(items["inventory"])
        XCTAssertNil(skein.nodeToReport)
        skein.activeItem = inventory
        for item in [skein.rootItem, look, inventory] {
            item.ideal = item.actual
        }
        XCTAssertTrue(skein.nodeToReport === inventory)
        look.ideal = "A different library"
        XCTAssertTrue(skein.nodeToReport === look)
        skein.rootItem.ideal = "Somewhere else"
        XCTAssertTrue(skein.nodeToReport === skein.rootItem)
    }

    func testReportState() throws {
        let (skein, items) = skeinWithKnots()
        let look = try XCTUnwrap(items["look"])
        let inventory = try XCTUnwrap(items["inventory"])
        XCTAssertEqual(skein.reportStateForSkein, "cursed", "The first knot isn't blessed")
        for item in [skein.rootItem, look, inventory] {
            item.ideal = item.actual
        }
        XCTAssertEqual(skein.reportStateForSkein, "right")
        skein.activeItem = inventory
        XCTAssertEqual(skein.reportStateForSkein, "right")
        look.ideal = "A different library"
        XCTAssertEqual(skein.reportStateForSkein, "wrong")
        skein.activeItem = try XCTUnwrap(items["jump"])
        XCTAssertEqual(skein.reportStateForSkein, "wrong", "The jump knot isn't blessed")
        skein.activeItem = nil
        XCTAssertEqual(skein.reportStateForSkein, "right")
    }

    func testWinningItem() throws {
        let (skein, items) = skeinWithKnots()
        let look = try XCTUnwrap(items["look"])
        XCTAssertTrue(skein.isTheWinning(nil))
        skein.winningItem = look
        XCTAssertTrue(skein.isTheWinning(look))
        XCTAssertFalse(skein.isTheWinning(skein.rootItem))
        XCTAssertFalse(skein.isTheWinning(nil))
    }

    // MARK: - Playing to a knot

    /// Everything an input source would type, in order.
    private func typed(_ source: ZoomViewInputSource) -> [String] {
        var typed: [String] = []
        while let command = source.nextCommand?() {
            typed.append(command)
        }
        return typed
    }

    func testInputSource() throws {
        let (skein, items) = skeinWithKnots()
        let look = try XCTUnwrap(items["look"])
        let inventory = try XCTUnwrap(items["inventory"])
        XCTAssertEqual(typed(try XCTUnwrap(IFSkein.inputSource(from: skein.rootItem, to: inventory))),
                       ["look", "inventory"])
        XCTAssertEqual(typed(try XCTUnwrap(IFSkein.inputSource(from: look, to: inventory))),
                       ["inventory"])
        XCTAssertEqual(typed(try XCTUnwrap(IFSkein.inputSource(from: look, to: look))), [])
        XCTAssertNil(IFSkein.inputSource(from: inventory, to: look), "Not above it")
        XCTAssertNil(IFSkein.inputSource(from: try XCTUnwrap(items["jump"]), to: inventory), "On another thread")
        XCTAssertNil(IFSkein.inputSource(from: nil, to: look))
        XCTAssertNil(IFSkein.inputSource(from: look, to: nil))
    }

    // MARK: - Undo

    /// Each change a knot registers for undo is made by the skein.
    func testUndoHelpers() throws {
        let (skein, items) = skeinWithKnots()
        let look = try XCTUnwrap(items["look"])
        skein.setCommandOf(look, command: "examine")
        XCTAssertEqual(look.command, "examine")
        skein.setActualOf(look, actual: "A library")
        XCTAssertEqual(look.actual, "A library")
        skein.setIdealOf(look, ideal: "The library")
        XCTAssertEqual(look.ideal, "The library")
        skein.setIsTestSubItemWithNSNumberOf(look, isTestSubItemWith: NSNumber(value: true))
        XCTAssertTrue(look.isTestSubItem)

        skein.remove(fromChildrenArrayOf: skein.rootItem, itemToRemove: look)
        XCTAssertEqual(skein.rootItem.children.map { $0.command }, ["jump"])
        skein.add(toChildrenArrayOf: skein.rootItem, itemToAdd: look)
        XCTAssertEqual(skein.rootItem.children.map { $0.command }, ["examine", "jump"])
        skein.setParentOf(look, parent: nil)
        XCTAssertNil(look.parent)
    }

    /// After an undo or redo, the skein tells its observers, if the undo changed it.
    func testUndoTellsObservers() {
        let skein: IFSkein = IFSkein(project: nil)
        let observer = Observer(skein)
        defer { observer.stop() }
        let undoManager = UndoManager()

        // A new skein needs laying out
        NotificationCenter.default.post(name: .NSUndoManagerDidUndoChange, object: undoManager)
        XCTAssertEqual(observer.changes, ["animate true, keep visible true"])
        NotificationCenter.default.post(name: .NSUndoManagerDidUndoChange, object: undoManager)
        NotificationCenter.default.post(name: .NSUndoManagerDidRedoChange, object: undoManager)
        XCTAssertEqual(observer.changes.count, 1)

        skein.setLayoutDirty()
        NotificationCenter.default.post(name: .NSUndoManagerDidRedoChange, object: undoManager)
        XCTAssertEqual(observer.changes.count, 2)
        skein.rootItem.command = "- begin -"
        NotificationCenter.default.post(name: .NSUndoManagerDidUndoChange, object: undoManager)
        XCTAssertEqual(observer.changes, ["animate true, keep visible true", "animate true, keep visible true", "animate true, keep visible true"])
    }
}
