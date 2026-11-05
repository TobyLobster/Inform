//
//  IFSettingTests.swift
//  InformTests
//

import XCTest

/// A setting that counts the times it's asked to show the compiler settings
private final class CountingSetting: IFSetting {
    var updates = 0

    override init() {
        super.init()
    }

    override func updateFromCompilerSettings() {
        updates += 1
    }
}

final class IFSettingTests: XCTestCase {
    // MARK: - Helpers

    private func pane(_ name: String, of settings: IFCompilerSettings) throws -> IFSetting {
        let paneClass: AnyClass = try XCTUnwrap(NSClassFromString(name), name)
        return try XCTUnwrap(settings.setting(for: paneClass), name)
    }

    private func outlet<T>(_ name: String, of pane: IFSetting, as type: T.Type) throws -> T {
        return try XCTUnwrap(pane.value(forKey: name) as? T, name)
    }

    private func notifications(named name: NSNotification.Name, from object: AnyObject, during block: () -> Void) -> Int {
        var count = 0
        let observer = NotificationCenter.default.addObserver(forName: name, object: object, queue: nil) { _ in
            count += 1
        }
        block()
        NotificationCenter.default.removeObserver(observer)
        return count
    }

    private struct Compiler {
        let id: String
        let displayName: String
        let description: String
    }

    private func compilerList() throws -> [Compiler] {
        let listClass: AnyClass = try XCTUnwrap(NSClassFromString("Inform.CompilerList"))
        let entries = try XCTUnwrap((listClass as AnyObject).value(forKey: "compilerList") as? [NSObject])
        return try entries.map { entry in
            Compiler(id: try XCTUnwrap(entry.value(forKey: "id") as? String),
                     displayName: try XCTUnwrap(entry.value(forKey: "displayName") as? String),
                     description: entry.description)
        }
    }

    // MARK: - The base class

    func testABareSetting() {
        let setting = IFSetting(nibName: nil)

        XCTAssertEqual(setting.title, "Setting")
        XCTAssertNil(setting.compilerSettings)
        XCTAssertNil(setting.dictionary())
        XCTAssertNil(setting.plistEntries)
        XCTAssertTrue(setting.enable(forCompiler: IFCompilerInform6))
        XCTAssertTrue(setting.enable(forCompiler: IFCompilerNaturalInform))

        // These do nothing
        setting.setSettings()
        setting.updateFromCompilerSettings()
    }

    func testASettingUsesItsCompilerSettingsDictionary() throws {
        let settings = IFCompilerSettings()
        let misc = try pane("IFMiscSettings", of: settings)

        XCTAssertTrue(misc.compilerSettings === settings)
        let dictionary = try XCTUnwrap(misc.dictionary())
        XCTAssertTrue(dictionary === settings.dictionary(for: type(of: misc)))

        // Its plist entries are the dictionary itself, not a copy
        XCTAssertTrue(misc.plistEntries === dictionary)
    }

    func testChangesAreNotifiedOnce() {
        let setting = IFSetting(nibName: nil)
        var count = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFSettingHasChanged, object: setting, queue: nil) { _ in
            count += 1

            // A change while the last one is being handled isn't notified
            setting.settingsHaveChanged(nil)
        }

        setting.settingsHaveChanged(nil)
        setting.settingsHaveChanged(self)
        NotificationCenter.default.removeObserver(observer)

        XCTAssertEqual(count, 2)
    }

    func testUpdatingFromPlistEntries() throws {
        let settings = IFCompilerSettings()
        let setting = CountingSetting()
        setting.compilerSettings = settings
        let dictionary = try XCTUnwrap(setting.dictionary())
        dictionary["Old"] = 1

        // No entries leave the settings alone
        setting.update(settings, withPlistEntries: nil)
        setting.update(settings, withPlistEntries: [:])
        XCTAssertEqual(setting.updates, 0)
        XCTAssertEqual(dictionary["Old"] as? Int, 1)

        // Entries replace what was there, and the setting shows them
        setting.update(settings, withPlistEntries: ["New": 2])
        XCTAssertEqual(setting.updates, 1)
        XCTAssertEqual(dictionary.count, 1)
        XCTAssertEqual(dictionary["New"] as? Int, 2)
    }

    func testUpdatingWithNoCompilerSettings() {
        let setting = CountingSetting()

        setting.update(IFCompilerSettings(), withPlistEntries: ["New": 2])

        XCTAssertEqual(setting.updates, 1)
        XCTAssertNil(setting.dictionary())
    }

    // MARK: - Miscellaneous settings

    func testMiscSettings() throws {
        let settings = IFCompilerSettings()
        let misc = try XCTUnwrap(try pane("IFMiscSettings", of: settings) as? IFMiscSettings)

        XCTAssertEqual(misc.title, IFUtility.localizedString("Misc Settings"))
        XCTAssertNotNil(misc.value(forKey: "settingView") as? NSView)
        XCTAssertTrue(misc.enable(forCompiler: IFCompilerInform6))
        XCTAssertFalse(misc.enable(forCompiler: IFCompilerNaturalInform))

        // With nothing set, strict and debug are on, and infix off
        XCTAssertTrue(misc.strict)
        XCTAssertFalse(misc.infix)
        XCTAssertTrue(misc.debug)
    }

    func testMiscSettingsAreKeptInTheDictionary() throws {
        let settings = IFCompilerSettings()
        let misc = try XCTUnwrap(try pane("IFMiscSettings", of: settings) as? IFMiscSettings)

        let changes = notifications(named: .IFSettingHasChanged, from: misc) {
            misc.strict = false
            misc.infix = true
            misc.debug = false
        }

        XCTAssertEqual(changes, 3)
        let dictionary = try XCTUnwrap(misc.dictionary())
        XCTAssertEqual(dictionary[IFSettingStrict] as? Bool, false)
        XCTAssertEqual(dictionary[IFSettingInfix] as? Bool, true)
        XCTAssertEqual(dictionary[IFSettingDEBUG] as? Bool, false)
        XCTAssertFalse(misc.strict)
        XCTAssertTrue(misc.infix)
        XCTAssertFalse(misc.debug)

        // The compiler settings read the same values
        XCTAssertFalse(settings.strict)
        XCTAssertTrue(settings.infix)
    }

    func testMiscSettingsInTheirView() throws {
        let settings = IFCompilerSettings()
        let misc = try XCTUnwrap(try pane("IFMiscSettings", of: settings) as? IFMiscSettings)
        let strictMode = try outlet("strictMode", of: misc, as: NSButton.self)
        let infixMode = try outlet("infixMode", of: misc, as: NSButton.self)
        let debugMode = try outlet("debugMode", of: misc, as: NSButton.self)

        misc.strict = false
        misc.infix = true
        misc.debug = true
        misc.updateFromCompilerSettings()

        XCTAssertEqual(strictMode.state, .off)
        XCTAssertEqual(debugMode.state, .on)

        // Projects are always Inform 7, so infix is turned off, and can't be turned on
        XCTAssertEqual(infixMode.state, .off)
        XCTAssertFalse(infixMode.isEnabled)
        XCTAssertFalse(misc.infix)

        strictMode.state = .on
        debugMode.state = .off
        misc.setSettings()

        XCTAssertTrue(misc.strict)
        XCTAssertFalse(misc.infix)
        XCTAssertFalse(misc.debug)
    }

    // MARK: - Compiler options

    func testCompilerOptions() throws {
        let settings = IFCompilerSettings()
        let options = try pane("IFCompilerOptions", of: settings)
        let naturalInform = try outlet("naturalInform", of: options, as: NSButton.self)

        XCTAssertEqual(options.title, IFUtility.localizedString("Compiler Settings"))
        XCTAssertTrue(options.enable(forCompiler: IFCompilerInform6))
        XCTAssertFalse(options.enable(forCompiler: IFCompilerNaturalInform))

        options.updateFromCompilerSettings()
        XCTAssertEqual(naturalInform.state, .on)

        // Turning it off changes nothing, as projects are always Inform 7
        naturalInform.state = .off
        options.setSettings()
        XCTAssertTrue(settings.usingNaturalInform)
    }

    // MARK: - Output settings

    private func checkOutputSettings(_ name: String, formats: [Int], forNaturalInform: Bool) throws {
        let settings = IFCompilerSettings()
        let output = try pane(name, of: settings)
        let zmachineVersion = try outlet("zmachineVersion", of: output, as: NSMatrix.self)
        let releaseBlorb = try outlet("releaseBlorb", of: output, as: NSButton.self)

        XCTAssertEqual(output.title, IFUtility.localizedString("Output Settings"), name)
        XCTAssertEqual(output.enable(forCompiler: IFCompilerInform6), !forNaturalInform, name)
        XCTAssertEqual(output.enable(forCompiler: IFCompilerNaturalInform), forNaturalInform, name)

        // Releases are bound up in a Blorb file unless that's turned off
        XCTAssertEqual(output.value(forKey: "createBlorbForRelease") as? Bool, true, name)
        let changes = notifications(named: .IFSetting, from: settings) {
            output.setValue(false, forKey: "createBlorbForRelease")
        }
        XCTAssertEqual(changes, 1, name)
        XCTAssertEqual(output.value(forKey: "createBlorbForRelease") as? Bool, false, name)
        XCTAssertEqual(settings.dictionary(for: type(of: output))[IFSettingCreateBlorb] as? Bool, false, name)

        // The view offers each format the compiler supports, and shows the settings
        settings.zcodeVersion = 8
        output.updateFromCompilerSettings()
        XCTAssertEqual(zmachineVersion.cells.map(\.tag), formats, name)
        XCTAssertTrue(zmachineVersion.cells.allSatisfy(\.isEnabled), name)
        XCTAssertEqual(zmachineVersion.selectedCell()?.tag, 8, name)
        XCTAssertEqual(releaseBlorb.state, .off, name)

        // And the settings come from the view
        zmachineVersion.selectCell(withTag: 256)
        releaseBlorb.state = .on
        output.setSettings()
        XCTAssertEqual(settings.zcodeVersion, 256, name)
        XCTAssertEqual(output.value(forKey: "createBlorbForRelease") as? Bool, true, name)
    }

    func testOutputSettings() throws {
        try checkOutputSettings("IFOutputSettings", formats: [5, 6, 8, 256], forNaturalInform: false)
    }

    func testInform7OutputSettings() throws {
        try checkOutputSettings("IFI7OutputSettings", formats: [8, 256], forNaturalInform: true)
    }

    func testAFormatNotOfferedIsKept() throws {
        for (name, version) in [("IFOutputSettings", 7), ("IFI7OutputSettings", 5)] {
            let settings = IFCompilerSettings()
            let output = try pane(name, of: settings)
            let zmachineVersion = try outlet("zmachineVersion", of: output, as: NSMatrix.self)
            let releaseBlorb = try outlet("releaseBlorb", of: output, as: NSButton.self)

            settings.zcodeVersion = Int32(version)
            output.updateFromCompilerSettings()
            XCTAssertNil(zmachineVersion.selectedCell(), name)

            // Changing whether to make a Blorb file leaves the format alone
            releaseBlorb.state = .off
            output.setSettings()
            XCTAssertEqual(settings.zcodeVersion, Int32(version), name)
            XCTAssertEqual(output.value(forKey: "createBlorbForRelease") as? Bool, false, name)
        }
    }

    func testOutputSettingsWithNoCompilerSettings() {
        let output = IFI7OutputSettings(nibName: nil)

        output.createBlorbForRelease = false

        XCTAssertTrue(output.createBlorbForRelease)
    }

    // MARK: - Compiler version settings

    func testCompilerVersionSettings() throws {
        let settings = IFCompilerSettings()
        let versions = try pane("IFCompilerVersionSettings", of: settings)

        XCTAssertEqual(versions.title, IFUtility.localizedString("Compiler Version Settings"))
        XCTAssertFalse(versions.enable(forCompiler: IFCompilerInform6))
        XCTAssertTrue(versions.enable(forCompiler: IFCompilerNaturalInform))
    }

    func testCompilerVersionsInTheirView() throws {
        let settings = IFCompilerSettings()
        let versions = try pane("IFCompilerVersionSettings", of: settings)
        let compilerVersionBox = try outlet("compilerVersionBox", of: versions, as: NSPopUpButton.self)
        let descriptionText = try outlet("descriptionText", of: versions, as: NSTextField.self)
        let compilers = try compilerList()
        let first = try XCTUnwrap(compilers.first)
        let last = try XCTUnwrap(compilers.last)
        XCTAssertGreaterThan(compilers.count, 1)

        // The view lists every compiler, once, and shows the one chosen
        settings.compilerVersion = last.id
        versions.updateFromCompilerSettings()
        versions.updateFromCompilerSettings()
        XCTAssertEqual(compilerVersionBox.itemTitles, compilers.map(\.displayName))
        XCTAssertEqual(compilerVersionBox.titleOfSelectedItem, last.displayName)
        XCTAssertEqual(descriptionText.stringValue, last.description)

        // A version not in the list shows the first, and is kept
        settings.compilerVersion = "No such version"
        versions.updateFromCompilerSettings()
        XCTAssertEqual(compilerVersionBox.titleOfSelectedItem, first.displayName)
        XCTAssertEqual(descriptionText.stringValue, first.description)
        XCTAssertEqual(settings.compilerVersion, "No such version")

        // The settings come from the view
        compilerVersionBox.selectItem(withTitle: last.displayName)
        versions.setSettings()
        XCTAssertEqual(settings.compilerVersion, last.id)

        // Choosing a compiler shows its description, and sets it
        compilerVersionBox.selectItem(withTitle: first.displayName)
        versions.perform(NSSelectorFromString("compilerVersionChanged:"), with: compilerVersionBox)
        XCTAssertEqual(descriptionText.stringValue, first.description)
        XCTAssertEqual(settings.compilerVersion, first.id)
    }

    // MARK: - The panes written in Swift

    func testTheSwiftPanes() throws {
        let settings = IFCompilerSettings()
        let advanced = try pane("Inform.IFAdvancedSettings", of: settings)
        let random = try pane("Inform.IFRandomSettings", of: settings)
        let basic = try pane("Inform.IFBasicInformSettings", of: settings)

        XCTAssertEqual(advanced.title, IFUtility.localizedString("Extensions Settings"))
        XCTAssertEqual(random.title, IFUtility.localizedString("Randomness Settings"))
        XCTAssertEqual(basic.title, IFUtility.localizedString("Basic Inform"))
        XCTAssertTrue(advanced.enable(forCompiler: IFCompilerInform6))
        XCTAssertTrue(advanced.enable(forCompiler: IFCompilerNaturalInform))
        XCTAssertFalse(random.enable(forCompiler: IFCompilerInform6))
        XCTAssertTrue(random.enable(forCompiler: IFCompilerNaturalInform))
        XCTAssertFalse(basic.enable(forCompiler: IFCompilerInform6))
        XCTAssertTrue(basic.enable(forCompiler: IFCompilerNaturalInform))
    }

    func testTheSwiftPanesInTheirViews() throws {
        let settings = IFCompilerSettings()
        let allowLegacyExtensionDirectory = try outlet("allowLegacyExtensionDirectory", of: try pane("Inform.IFAdvancedSettings", of: settings), as: NSButton.self)
        let makePredictable = try outlet("makePredictable", of: try pane("Inform.IFRandomSettings", of: settings), as: NSButton.self)
        let basicInform = try outlet("basicInform", of: try pane("Inform.IFBasicInformSettings", of: settings), as: NSButton.self)
        let panes = try ["Inform.IFAdvancedSettings", "Inform.IFRandomSettings", "Inform.IFBasicInformSettings"].map {
            try pane($0, of: settings)
        }

        settings.allowLegacyExtensionDirectory = true
        settings.nobbleRng = true
        settings.basicInform = true
        panes.forEach { $0.updateFromCompilerSettings() }

        XCTAssertEqual(allowLegacyExtensionDirectory.state, .on)
        XCTAssertEqual(makePredictable.state, .on)
        XCTAssertEqual(basicInform.state, .on)

        allowLegacyExtensionDirectory.state = .off
        makePredictable.state = .off
        basicInform.state = .off
        panes.forEach { $0.setSettings() }

        XCTAssertFalse(settings.allowLegacyExtensionDirectory)
        XCTAssertFalse(settings.nobbleRng)
        XCTAssertFalse(settings.basicInform)
    }
}
