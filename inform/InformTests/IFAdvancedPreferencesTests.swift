//
//  IFAdvancedPreferencesTests.swift
//  InformTests
//

import XCTest

/// User defaults kept in memory, so that the tests never read or write the user's own
private final class MemoryDefaults: UserDefaults {
    var values: [String: Any]

    init(_ values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "IFAdvancedPreferencesTests.never-written")!
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

/// The Advanced pane's controls, from its nib
private struct Controls {
    let showDebugLogs: NSButton
    let runBuildSh: NSButton
    let alwaysCompile: NSButton
    let showConsole: NSButton
    let publicLibraryDebug: NSButton
    let useExternalInformCore: NSButton
    let externalInformCoreDirectory: NSTextField
    let cleanBuildFiles: NSButton
    let alsoCleanIndexFiles: NSButton
    let glulxInterpreter: NSPopUpButton

    init(_ pane: IFAdvancedPreferences) throws {
        func control<T>(_ name: String) throws -> T {
            return try XCTUnwrap(pane.value(forKey: name) as? T, name)
        }
        showDebugLogs = try control("showDebugLogs")
        runBuildSh = try control("runBuildSh")
        alwaysCompile = try control("alwaysCompile")
        showConsole = try control("showConsole")
        publicLibraryDebug = try control("publicLibraryDebug")
        useExternalInformCore = try control("useExternalInformCore")
        externalInformCoreDirectory = try control("externalInformCoreDirectory")
        cleanBuildFiles = try control("cleanBuildFiles")
        alsoCleanIndexFiles = try control("alsoCleanIndexFiles")
        glulxInterpreter = try control("glulxInterpreter")
    }

    /// The check boxes, with the preference each shows
    var checkBoxes: [(button: NSButton, key: String, get: (IFPreferences) -> Bool)] {
        return [(showDebugLogs, "showDebuggingLogs", { $0.showDebuggingLogs }),
                (runBuildSh, "runBuildSh", { $0.runBuildSh }),
                (alwaysCompile, "alwaysCompile", { $0.alwaysCompile }),
                (showConsole, "showConsoleDuringBuilds", { $0.showConsoleDuringBuilds }),
                (publicLibraryDebug, "publicLibraryDebug", { $0.publicLibraryDebug }),
                (useExternalInformCore, "useExternalInformCoreDirectory", { $0.useExternalInformCoreDirectory }),
                (cleanBuildFiles, "cleanProjectOnClose", { $0.cleanProjectOnClose }),
                (alsoCleanIndexFiles, "alsoCleanIndexFiles", { $0.alsoCleanIndexFiles })]
    }
}

final class IFAdvancedPreferencesTests: XCTestCase {
    /// A pane for preferences kept in memory, which start with the values given
    private func makePane(_ stored: [String: Any] = [:]) throws -> (IFAdvancedPreferences, IFPreferences, MemoryDefaults, Controls) {
        let defaults = MemoryDefaults([IFPreferencesDefault: stored])
        let preferences = IFPreferences(userDefaults: defaults)
        let pane = IFAdvancedPreferences(preferences: preferences)
        return (pane, preferences, defaults, try Controls(pane))
    }

    /// The dictionary the preferences last wrote to their user defaults
    private func written(_ defaults: MemoryDefaults) -> [String: Any] {
        return defaults.values[IFPreferencesDefault] as? [String: Any] ?? [:]
    }

    /// Clicks a check box, as its user would
    private func click(_ button: NSButton, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(button.isEnabled, "a disabled check box can't be clicked", file: file, line: line)
        button.performClick(nil)
    }

    /// Chooses an item from the interpreter menu, as its user would
    private func choose(_ index: Int, in popUp: NSPopUpButton) {
        popUp.selectItem(at: index)
        NSApp.sendAction(popUp.action!, to: popUp.target, from: popUp)
    }

    private func isOn(_ button: NSButton) -> Bool {
        return button.state == .on
    }

    // MARK: - The toolbar item

    func testThePaneIsNamedAdvanced() throws {
        let (pane, _, _, _) = try makePane()
        XCTAssertEqual(pane.preferenceName, "Advanced")
        XCTAssertEqual(pane.tooltip, IFUtility.localizedString("Advanced preferences tooltip"))
        XCTAssertNotEqual(pane.tooltip, "Advanced preferences tooltip")
        XCTAssertNotNil(pane.toolbarImage)
    }

    func testThePaneLoadsItsNib() throws {
        let (pane, _, _, _) = try makePane()
        let view = try XCTUnwrap(pane.preferenceView)
        XCTAssertGreaterThan(pane.maxHeight, 0)
        XCTAssertEqual(pane.maxHeight, view.frame.height)
    }

    // MARK: - Showing the preferences

    func testTheCheckBoxesShowThePreferences() throws {
        let (_, _, _, off) = try makePane(["showDebuggingLogs": false, "runBuildSh": false, "alwaysCompile": false,
                                           "showConsoleDuringBuilds": false, "publicLibraryDebug": false,
                                           "useExternalInformCoreDirectory": false, "cleanProjectOnClose": false,
                                           "alsoCleanIndexFiles": false])
        for (button, key, _) in off.checkBoxes {
            XCTAssertFalse(isOn(button), key)
        }

        let (_, _, _, on) = try makePane(["showDebuggingLogs": true, "runBuildSh": true, "alwaysCompile": true,
                                          "showConsoleDuringBuilds": true, "publicLibraryDebug": true,
                                          "useExternalInformCoreDirectory": true, "cleanProjectOnClose": true,
                                          "alsoCleanIndexFiles": true])
        for (button, key, _) in on.checkBoxes {
            XCTAssertTrue(isOn(button), key)
        }
    }

    /// With no preferences set, only cleaning build files is on
    func testTheDefaultPreferences() throws {
        let (_, _, _, controls) = try makePane()
        for (button, key, _) in controls.checkBoxes {
            XCTAssertEqual(isOn(button), key == "cleanProjectOnClose", key)
        }
        XCTAssertTrue(controls.alsoCleanIndexFiles.isEnabled)
        XCTAssertEqual(controls.glulxInterpreter.indexOfSelectedItem, 0)
        XCTAssertEqual(controls.externalInformCoreDirectory.stringValue, "")
    }

    /// Index files are only cleaned as well as build files, so that check box is off and disabled while
    /// build files aren't cleaned, whatever its preference
    func testAlsoCleaningIndexFilesNeedsCleaningBuildFiles() throws {
        let (_, _, _, controls) = try makePane(["cleanProjectOnClose": false, "alsoCleanIndexFiles": true])
        XCTAssertFalse(isOn(controls.alsoCleanIndexFiles))
        XCTAssertFalse(controls.alsoCleanIndexFiles.isEnabled)

        let (_, _, _, cleaning) = try makePane(["cleanProjectOnClose": true, "alsoCleanIndexFiles": true])
        XCTAssertTrue(isOn(cleaning.alsoCleanIndexFiles))
        XCTAssertTrue(cleaning.alsoCleanIndexFiles.isEnabled)
    }

    /// Rebuilding the compiler and the debugging Public Library don't work in the sandbox
    func testSomeCheckBoxesAreHiddenInTheSandbox() throws {
        let (_, _, _, controls) = try makePane()
        XCTAssertEqual(controls.runBuildSh.isHidden, IFUtility.isSandboxed)
        XCTAssertEqual(controls.publicLibraryDebug.isHidden, IFUtility.isSandboxed)
        for (button, key, _) in controls.checkBoxes where button !== controls.runBuildSh && button !== controls.publicLibraryDebug {
            XCTAssertFalse(button.isHidden, key)
        }
    }

    func testTheInterpreterMenuListsTheAppsInterpreters() throws {
        let (_, _, _, controls) = try makePane()
        let items = controls.glulxInterpreter.itemArray
        XCTAssertEqual(items.map(\.title), ["Glulxe (default)", "git"])
        XCTAssertEqual(items.map(\.tag), [0, 1])
    }

    func testTheInterpreterMenuShowsThePreference() throws {
        let (_, _, _, git) = try makePane(["glulxInterpreter": "git"])
        XCTAssertEqual(git.glulxInterpreter.indexOfSelectedItem, 1)

        let (_, _, _, glulxe) = try makePane(["glulxInterpreter": "glulxe"])
        XCTAssertEqual(glulxe.glulxInterpreter.indexOfSelectedItem, 0)
    }

    /// An interpreter the app doesn't have shows as the first
    func testAnUnknownInterpreterShowsAsTheFirst() throws {
        let (_, _, _, controls) = try makePane(["glulxInterpreter": "frotz"])
        XCTAssertEqual(controls.glulxInterpreter.indexOfSelectedItem, 0)
        XCTAssertEqual(controls.glulxInterpreter.itemArray.count, 2)
    }

    func testTheInformCoreDirectoryShowsThePreference() throws {
        let (_, _, _, unused) = try makePane(["useExternalInformCoreDirectory": false,
                                              "externalInformCoreDirectory": "/Users/emily/inform"])
        XCTAssertEqual(unused.externalInformCoreDirectory.stringValue, "/Users/emily/inform")
        XCTAssertEqual(unused.externalInformCoreDirectory.textColor, NSColor.disabledControlTextColor)

        let (_, _, _, used) = try makePane(["useExternalInformCoreDirectory": true,
                                            "externalInformCoreDirectory": "/Users/emily/inform"])
        XCTAssertEqual(used.externalInformCoreDirectory.stringValue, "/Users/emily/inform")
        XCTAssertEqual(used.externalInformCoreDirectory.textColor, NSColor.controlTextColor)
    }

    /// The pane shows changes made elsewhere, and rebuilds its menu without repeating it
    func testThePaneFollowsThePreferences() throws {
        let (_, preferences, _, controls) = try makePane()

        preferences.showDebuggingLogs = true
        preferences.glulxInterpreter = "git"
        preferences.cleanProjectOnClose = false
        preferences.useExternalInformCoreDirectory = true
        preferences.externalInformCoreDirectory = "/Users/emily/inform"

        XCTAssertTrue(isOn(controls.showDebugLogs))
        XCTAssertEqual(controls.glulxInterpreter.indexOfSelectedItem, 1)
        XCTAssertEqual(controls.glulxInterpreter.itemArray.count, 2)
        XCTAssertFalse(isOn(controls.cleanBuildFiles))
        XCTAssertFalse(controls.alsoCleanIndexFiles.isEnabled)
        XCTAssertTrue(isOn(controls.useExternalInformCore))
        XCTAssertEqual(controls.externalInformCoreDirectory.stringValue, "/Users/emily/inform")
        XCTAssertEqual(controls.externalInformCoreDirectory.textColor, NSColor.controlTextColor)
    }

    /// Only the preferences given are shown, not the shared ones
    func testThePaneIgnoresOtherPreferences() throws {
        let (_, _, _, controls) = try makePane()
        let other = IFPreferences(userDefaults: MemoryDefaults())

        other.showDebuggingLogs = true

        XCTAssertFalse(isOn(controls.showDebugLogs))
    }

    // MARK: - Setting the preferences

    func testEachCheckBoxSetsItsPreference() throws {
        let count = try makePane().3.checkBoxes.count
        for index in 0..<count {
            let (_, preferences, defaults, controls) = try makePane(["alsoCleanIndexFiles": true])
            let (button, key, get) = controls.checkBoxes[index]
            let before = get(preferences)

            click(button)

            XCTAssertEqual(get(preferences), !before, key)
            XCTAssertEqual(isOn(button), !before, key)
            XCTAssertEqual(written(defaults)[key] as? Bool, !before, key)
        }
    }

    /// A click writes the state of every control, not only its own
    func testAClickWritesEveryPreference() throws {
        let (_, _, defaults, controls) = try makePane()

        click(controls.showConsole)

        let written = written(defaults)
        XCTAssertEqual(written["showDebuggingLogs"] as? Bool, false)
        XCTAssertEqual(written["runBuildSh"] as? Bool, false)
        XCTAssertEqual(written["alwaysCompile"] as? Bool, false)
        XCTAssertEqual(written["showConsoleDuringBuilds"] as? Bool, true)
        XCTAssertEqual(written["publicLibraryDebug"] as? Bool, false)
        XCTAssertEqual(written["cleanProjectOnClose"] as? Bool, true)
        XCTAssertEqual(written["alsoCleanIndexFiles"] as? Bool, false)
        XCTAssertEqual(written["glulxInterpreter"] as? String, "glulxe")
        XCTAssertEqual(written["useExternalInformCoreDirectory"] as? Bool, false)
        XCTAssertEqual(written["externalInformCoreDirectory"] as? String, "")
    }

    func testChoosingAnInterpreterSetsItsPreference() throws {
        let (_, preferences, defaults, controls) = try makePane()

        choose(1, in: controls.glulxInterpreter)
        XCTAssertEqual(preferences.glulxInterpreter, "git")
        XCTAssertEqual(written(defaults)["glulxInterpreter"] as? String, "git")

        choose(0, in: controls.glulxInterpreter)
        XCTAssertEqual(preferences.glulxInterpreter, "glulxe")
    }

    /// Cleaning build files enables cleaning index files too
    func testCleaningBuildFilesEnablesCleaningIndexFiles() throws {
        let (_, preferences, _, controls) = try makePane(["cleanProjectOnClose": false])

        click(controls.cleanBuildFiles)
        XCTAssertTrue(preferences.cleanProjectOnClose)
        XCTAssertTrue(controls.alsoCleanIndexFiles.isEnabled)

        click(controls.alsoCleanIndexFiles)
        XCTAssertTrue(preferences.alsoCleanIndexFiles)

        click(controls.cleanBuildFiles)
        XCTAssertFalse(preferences.cleanProjectOnClose)
        XCTAssertFalse(isOn(controls.alsoCleanIndexFiles))
        XCTAssertFalse(controls.alsoCleanIndexFiles.isEnabled)
    }

    /// Using the Inform Core directory keeps the directory, and shows it as usable
    func testUsingTheInformCoreDirectory() throws {
        let (_, preferences, _, controls) = try makePane(["externalInformCoreDirectory": "/Users/emily/inform"])

        click(controls.useExternalInformCore)
        XCTAssertTrue(preferences.useExternalInformCoreDirectory)
        XCTAssertEqual(preferences.externalInformCoreDirectory, "/Users/emily/inform")
        XCTAssertEqual(controls.externalInformCoreDirectory.textColor, NSColor.controlTextColor)

        click(controls.useExternalInformCore)
        XCTAssertFalse(preferences.useExternalInformCoreDirectory)
        XCTAssertEqual(preferences.externalInformCoreDirectory, "/Users/emily/inform")
        XCTAssertEqual(controls.externalInformCoreDirectory.textColor, NSColor.disabledControlTextColor)
    }

    /// setPreference: reads every control, whoever sends it
    func testSetPreferenceReadsTheControls() throws {
        let (pane, preferences, _, controls) = try makePane()

        controls.alwaysCompile.state = .on
        controls.glulxInterpreter.selectItem(at: 1)
        pane.setPreference(nil)

        XCTAssertTrue(preferences.alwaysCompile)
        XCTAssertEqual(preferences.glulxInterpreter, "git")
    }

    /// reflectCurrentPreferences puts back what the controls show
    func testReflectingThePreferencesUndoesChangesToTheControls() throws {
        let (pane, _, _, controls) = try makePane()

        controls.alwaysCompile.state = .on
        controls.glulxInterpreter.selectItem(at: 1)
        pane.reflectCurrentPreferences()

        XCTAssertFalse(isOn(controls.alwaysCompile))
        XCTAssertEqual(controls.glulxInterpreter.indexOfSelectedItem, 0)
    }
}
