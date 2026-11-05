//
//  IFCompilerSettingsTests.swift
//  InformTests
//

import XCTest

final class IFCompilerSettingsTests: XCTestCase {

    /// A project's Settings.plist, as the app writes it, with settings changed from their defaults.
    private let settingsFile = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        	<key>IFCompilerOptions</key>
        	<dict/>
        	<key>IFMiscSettings</key>
        	<dict>
        		<key>IFSettingStrict</key>
        		<false/>
        		<key>IFSettingInfix</key>
        		<true/>
        	</dict>
        	<key>IFOutputSettings</key>
        	<dict>
        		<key>IFSettingZCodeVersion</key>
        		<integer>8</integer>
        		<key>IFSettingCompilerVersion</key>
        		<string>6M62</string>
        		<key>IFSettingNobbleRng</key>
        		<true/>
        		<key>IFSettingBasicInform</key>
        		<true/>
        	</dict>
        	<key>Inform.IFAdvancedSettings</key>
        	<dict>
        		<key>IFSettingAllowLegacyExtensionDirectory</key>
        		<false/>
        	</dict>
        	<key>Inform.IFBasicInformSettings</key>
        	<dict/>
        	<key>Inform.IFRandomSettings</key>
        	<dict/>
        	<key>IFWindowsSettings</key>
        	<dict>
        		<key>Something</key>
        		<string>Only Windows knows</string>
        	</dict>
        </dict>
        </plist>
        """

    func testDefaults() {
        let settings = IFCompilerSettings()
        XCTAssertEqual(settings.zcodeVersion, 256)
        XCTAssertEqual(settings.fileExtension, "ulx")
        XCTAssertTrue(settings.strict)
        XCTAssertFalse(settings.infix)
        XCTAssertFalse(settings.nobbleRng)
        XCTAssertFalse(settings.basicInform)
        XCTAssertTrue(settings.allowLegacyExtensionDirectory)
        XCTAssertEqual(settings.compilerVersion, "")
    }

    func testReadsAProjectsSettings() throws {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.restore(fromPlist: Data(settingsFile.utf8)))

        XCTAssertEqual(settings.zcodeVersion, 8)
        XCTAssertEqual(settings.fileExtension, "z8")
        XCTAssertFalse(settings.strict)
        // Inform 7 projects can't use infix, so it's turned off
        XCTAssertFalse(settings.infix)
        XCTAssertTrue(settings.nobbleRng)
        XCTAssertTrue(settings.basicInform)
        XCTAssertFalse(settings.allowLegacyExtensionDirectory)
        XCTAssertEqual(settings.compilerVersion, "6M62")
    }

    /// Settings for a settings object that aren't a dictionary are passed over, and the rest are read.
    func testSettingsThatArentADictionaryArePassedOver() {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.restore(fromPlist: Data("""
            <plist version="1.0"><dict>
            <key>IFMiscSettings</key><string>Not settings</string>
            <key>IFOutputSettings</key><dict><key>IFSettingZCodeVersion</key><integer>8</integer></dict>
            </dict></plist>
            """.utf8)))
        XCTAssertEqual(settings.zcodeVersion, 8)
        XCTAssertTrue(settings.strict)
    }

    func testRejectsAFileThatIsNotSettings() {
        let settings = IFCompilerSettings()
        XCTAssertFalse(settings.restore(fromPlist: Data("not a property list".utf8)))
        XCTAssertFalse(settings.restore(fromPlist: Data("<plist version=\"1.0\"><array/></plist>".utf8)))
    }

    /// A project whose settings file (new or old style) is a folder, not a file, opens with the
    /// default settings.
    func testASettingsFolderGivesTheDefaults() throws {
        for name in ["Settings.plist", "Settings"] {
            let folder = FileWrapper(directoryWithFileWrappers: [:])
            folder.preferredFilename = name
            let project = FileWrapper(directoryWithFileWrappers: [name: folder])
            let projectFile = try XCTUnwrap(IFProjectFile(fileWrapper: project))

            let settings = try XCTUnwrap(projectFile.settings, name)
            XCTAssertEqual(settings.zcodeVersion, 256, name)
            XCTAssertTrue(settings.strict, name)
        }
    }

    /// Settings survive being saved and loaded, and settings from elsewhere (such as the
    /// Windows app) are kept.
    func testWritesWhatItReads() throws {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.restore(fromPlist: Data(settingsFile.utf8)))
        settings.zcodeVersion = 5
        settings.strict = true
        settings.compilerVersion = "6L38"

        let saved = try XCTUnwrap(settings.currentPlist)
        let copy = IFCompilerSettings()
        XCTAssertTrue(copy.restore(fromPlist: saved))
        XCTAssertEqual(copy.zcodeVersion, 5)
        XCTAssertTrue(copy.strict)
        XCTAssertFalse(copy.infix)
        XCTAssertTrue(copy.nobbleRng)
        XCTAssertTrue(copy.basicInform)
        XCTAssertFalse(copy.allowLegacyExtensionDirectory)
        XCTAssertEqual(copy.compilerVersion, "6L38")

        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: saved, format: nil) as? [String: Any])
        let windows = try XCTUnwrap(plist["IFWindowsSettings"] as? [String: String])
        XCTAssertEqual(windows["Something"], "Only Windows knows")
    }

    /// The switches given to the Inform 6 compiler.
    func testInform6Switches() {
        let settings = IFCompilerSettings()
        XCTAssertEqual(settings.commandLineArguments(forRelease: false, forTesting: false).first, "-kE2SDwG")
        XCTAssertEqual(settings.commandLineArguments(forRelease: true, forTesting: false).first, "-kE2~S~DwG")

        // Testing always checks strictly, and with debugging
        settings.strict = false
        XCTAssertEqual(settings.commandLineArguments(forRelease: false, forTesting: false).first, "-kE2~SDwG")
        XCTAssertEqual(settings.commandLineArguments(forRelease: true, forTesting: true).first, "-kE2SDwG")

        settings.strict = true
        settings.infix = true
        settings.zcodeVersion = 8
        XCTAssertEqual(settings.commandLineArguments(forRelease: false, forTesting: false).first, "-kE2SXDwv8")
        XCTAssertEqual(settings.commandLineArguments(forRelease: true, forTesting: false).first, "-kE2~S~Dwv8")

        XCTAssertEqual(settings.commandLineArguments(forRelease: false, forTesting: false).last?.hasPrefix("+include_path="), true)
        XCTAssertEqual(settings.commandLineArguments(forRelease: false, forTesting: false).last?.hasSuffix(",.,../Source"), true)
    }

    /// A version of the Z-machine the compiler doesn't support is replaced by the default.
    func testUnsupportedStoryFormat() {
        let settings = IFCompilerSettings()
        settings.zcodeVersion = 2
        XCTAssertEqual(settings.commandLineArguments(forRelease: false, forTesting: false).first, "-kE2SDwv5")
    }

    /// The arguments given to the Inform 7 compiler (the current version).
    func testInform7Arguments() throws {
        let settings = IFCompilerSettings()
        let arguments: [String] = settings.naturalInformCommandLineArguments
        let internalIndex = try XCTUnwrap(arguments.firstIndex(of: "-internal"))
        XCTAssertEqual(arguments[internalIndex + 1], IFUtility.path(forInformInternalAppSupport: ""))
        XCTAssertTrue(arguments.contains("-deprecated-external"))

        settings.allowLegacyExtensionDirectory = false
        XCTAssertFalse(settings.naturalInformCommandLineArguments.contains("-deprecated-external"))
    }

    /// The arguments given to older Inform 7 compilers.
    func testInform7ArgumentsForOlderVersions() {
        let settings = IFCompilerSettings()
        let external = IFUtility.pathForInformExternalAppSupport()

        settings.compilerVersion = "6L38"
        XCTAssertEqual(settings.naturalInformCommandLineArguments, [
            "-internal", IFUtility.path(forInformInternalAppSupport: "6L38"), "-deprecated-external", external])

        settings.compilerVersion = "6L02"
        XCTAssertEqual(settings.naturalInformCommandLineArguments, [
            "-extensions", external + "/Extensions",
            "-rules", IFUtility.path(forInformInternalAppSupport: "6L02") + "/Extensions", "-log"])

        settings.compilerVersion = "5Z71"
        XCTAssertEqual(settings.naturalInformCommandLineArguments, [
            "-rules", IFUtility.path(forInformInternalAppSupport: "5Z71") + "/Extensions", "-log"])
    }

    func testTheCompilersUsed() {
        let settings = IFCompilerSettings()
        for version in ["", "6M62", "6L02"] {
            settings.compilerVersion = version
            XCTAssertEqual(settings.naturalInformCompilerToUse, IFUtility.path(forCompiler: version), version)
            XCTAssertEqual(settings.inform6CompilerToUse,
                           IFUtility.path(forInformExecutable: "inform6", version: version), version)
            let ni = try? XCTUnwrap(settings.naturalInformCompilerToUse)
            XCTAssertEqual(settings.isNaturalInformCompilerPathValid(),
                           ni.map { FileManager.default.fileExists(atPath: $0) } ?? false, version)
        }

        // A version the app doesn't have
        settings.compilerVersion = "1A01"
        XCTAssertFalse(settings.isNaturalInformCompilerPathValid())
    }

    func testTheCompilerVersionCanBeCleared() {
        let settings = IFCompilerSettings()
        settings.compilerVersion = "6M62"
        settings.compilerVersion = nil
        XCTAssertEqual(settings.compilerVersion, "")
    }

    /// Projects are always Inform 7 now: the setting can't be turned off.
    func testProjectsAreAlwaysInform7() {
        let settings = IFCompilerSettings()
        settings.usingNaturalInform = false
        XCTAssertTrue(settings.usingNaturalInform)
        XCTAssertEqual(settings.primaryCompilerType, IFCompilerNaturalInform)
    }

    func testStoryFormats() {
        let settings = IFCompilerSettings()
        XCTAssertEqual(settings.supportedZMachines.map(\.intValue), [5, 3, 4, 6, 7, 8, 256])
        for (version, fileExtension) in [(5, "z5"), (8, "z8"), (256, "ulx"), (2, "z2")] {
            settings.zcodeVersion = Int32(version)
            XCTAssertEqual(settings.fileExtension, fileExtension)
        }
    }

    func testTheTestingTab() throws {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.testingTabHelpShown)
        XCTAssertEqual(settings.testingTabShownCount, 0)

        settings.testingTabHelpShown = false
        settings.testingTabShownCount = 3
        XCTAssertFalse(settings.testingTabHelpShown)
        XCTAssertEqual(settings.testingTabShownCount, 3)

        // They're saved with the miscellaneous settings
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: try XCTUnwrap(settings.currentPlist), format: nil) as? [String: Any])
        let misc = try XCTUnwrap(plist["IFMiscSettings"] as? [String: Any])
        XCTAssertEqual(misc["IFSettingTestingTabHelpShown"] as? Bool, false)
        XCTAssertEqual(misc["IFSettingTestingTabShownCount"] as? Int, 3)
    }

    /// Each change is notified, except showing the testing tab's help when it's already shown, and
    /// turning Inform 7 off, which does nothing.
    func testChangesAreNotified() {
        let settings = IFCompilerSettings()
        var notified = 0
        let observer = NotificationCenter.default.addObserver(forName: .IFSetting, object: settings,
                                                              queue: nil) { _ in
            notified += 1
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        settings.strict = false
        settings.infix = true
        settings.nobbleRng = true
        settings.basicInform = true
        settings.allowLegacyExtensionDirectory = false
        settings.zcodeVersion = 8
        settings.compilerVersion = "6M62"
        settings.testingTabShownCount = 2
        settings.settingsHaveChanged()
        XCTAssertEqual(notified, 9)

        settings.testingTabHelpShown = true
        settings.usingNaturalInform = false
        XCTAssertEqual(notified, 9)
        settings.testingTabHelpShown = false
        XCTAssertEqual(notified, 10)
    }

    // MARK: - Inform 6 libraries

    private var appLibraries: String {
        return (Bundle.main.resourcePath! as NSString).appendingPathComponent("Library")
    }

    /// The app's Standard library is a file naming the folder it's in.
    func testTheAppsLibrary() {
        XCTAssertEqual(IFCompilerSettings.inform6LibraryPaths, [IFUtility.pathForInformExternalLibraries(), appLibraries])
        XCTAssertEqual(IFCompilerSettings.path(forLibrary: "Standard"), appLibraries + "/6.11")
        XCTAssertEqual(IFCompilerSettings.path(forLibrary: "6.11"), appLibraries + "/6.11")
        XCTAssertNil(IFCompilerSettings.path(forLibrary: "Missing"))
        XCTAssertTrue(Set(IFCompilerSettings.availableLibraries).isSuperset(of: ["6.11", "Standard"]))
    }

    /// A library in the Libraries folder of Inform's Application Support comes before the app's, and a
    /// Natural library comes before the Standard one.
    func testLibrariesOfYourOwn() throws {
        try XCTSkipUnless(NSHomeDirectory().hasSuffix("/TestHome"), "Only writes in the tests' own home")
        let external = IFUtility.pathForInformExternalLibraries()
        let fileManager = FileManager.default
        XCTAssertFalse(fileManager.fileExists(atPath: external))
        try fileManager.createDirectory(atPath: external + "/Mine", withIntermediateDirectories: true)
        addTeardownBlock { try? fileManager.removeItem(atPath: external) }
        try "Mine".write(toFile: external + "/Natural", atomically: true, encoding: .utf8)
        try "6.11".write(toFile: external + "/Standard", atomically: true, encoding: .utf8)
        try "Gone".write(toFile: external + "/Broken", atomically: true, encoding: .utf8)
        try "Plain".write(toFile: external + "/Plain", atomically: true, encoding: .utf8)

        XCTAssertEqual(IFCompilerSettings.path(forLibrary: "Natural"), external + "/Mine")
        XCTAssertEqual(IFCompilerSettings.path(forLibrary: "Mine"), external + "/Mine")
        // A link to a folder that isn't there, or to a file, is passed over
        XCTAssertEqual(IFCompilerSettings.path(forLibrary: "Standard"), appLibraries + "/6.11")
        XCTAssertNil(IFCompilerSettings.path(forLibrary: "Broken"))
        XCTAssertNil(IFCompilerSettings.path(forLibrary: "Plain"))

        // So is a link that can't be read, rather than giving the Libraries folder itself
        try Data([0xFF, 0xFE, 0x41]).write(to: URL(fileURLWithPath: external + "/Garbled"))
        XCTAssertNil(IFCompilerSettings.path(forLibrary: "Garbled"))

        // Each name is listed once
        let available = IFCompilerSettings.availableLibraries
        XCTAssertEqual(available.filter { $0 == "Standard" }.count, 1)
        XCTAssertTrue(Set(available).isSuperset(of: ["Mine", "Natural", "Broken", "Plain", "6.11", "Standard"]))

        XCTAssertEqual(IFCompilerSettings().commandLineArguments(forRelease: false, forTesting: false).last,
                       "+include_path=\(external)/Mine,.,../Source")
    }

    /// Without its Natural library, the compiler includes the app's Standard one.
    func testTheLibraryIncluded() {
        try? XCTSkipIf(FileManager.default.fileExists(atPath: IFUtility.pathForInformExternalLibraries() + "/Natural"))
        XCTAssertEqual(IFCompilerSettings().commandLineArguments(forRelease: false, forTesting: false).last,
                       "+include_path=\(appLibraries)/6.11,.,../Source")
    }

    // MARK: - The settings objects

    private func settingsClass(_ name: String) throws -> AnyClass {
        return try XCTUnwrap(NSClassFromString(name), name)
    }

    func testEachSettingsObjectHasADictionary() throws {
        let settings = IFCompilerSettings()
        let misc = try settingsClass("IFMiscSettings")
        let setting = try XCTUnwrap(settings.setting(for: misc))
        XCTAssertTrue(type(of: setting) == misc)
        XCTAssertNotNil(settings.setting(for: try settingsClass("Inform.IFAdvancedSettings")))
        XCTAssertNil(settings.setting(for: NSString.self))

        let dictionary = settings.dictionary(for: misc)
        XCTAssertTrue(dictionary === settings.dictionary(for: misc))
        dictionary[IFSettingStrict] = false
        XCTAssertFalse(settings.strict)
        settings.infix = true
        XCTAssertEqual(dictionary[IFSettingInfix] as? Bool, true)
    }

    /// Without its settings objects, nothing is saved or read, but what was read is kept.
    func testWithoutSettingsObjects() throws {
        let settings = IFCompilerSettings()
        settings.setGeneric([])
        XCTAssertNil(settings.setting(for: try settingsClass("IFMiscSettings")))

        settings.strict = false
        var saved = try XCTUnwrap(settings.currentPlist)
        XCTAssertEqual((try PropertyListSerialization.propertyList(from: saved, format: nil) as? [String: Any])?.count, 0)

        XCTAssertTrue(settings.restore(fromPlist: Data(settingsFile.utf8)))
        XCTAssertEqual(settings.zcodeVersion, 256)
        XCTAssertFalse(settings.strict)
        saved = try XCTUnwrap(settings.currentPlist)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: saved, format: nil) as? [String: Any])
        XCTAssertEqual((plist["IFOutputSettings"] as? [String: Any])?[IFSettingZCodeVersion] as? Int, 8)
    }

    func testReloadingPutsBackWhatWasRead() throws {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.restore(fromPlist: Data(settingsFile.utf8)))
        settings.zcodeVersion = 5
        settings.strict = true

        settings.reload(forClass: "IFOutputSettings")
        XCTAssertEqual(settings.zcodeVersion, 8)
        XCTAssertTrue(settings.strict)

        settings.reload(forClass: "IFWindowsSettings")
        settings.reloadAllSettings()
        XCTAssertFalse(settings.strict)
    }

    /// Saving keeps each settings object's own dictionary as the settings read, so reloading afterwards
    /// (as a settings page does when it's given the settings) keeps changes made since.
    func testReloadingAfterSavingKeepsLaterChanges() throws {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.restore(fromPlist: Data(settingsFile.utf8)))
        XCTAssertNotNil(settings.currentPlist)
        settings.zcodeVersion = 5
        settings.strict = true

        settings.reloadAllSettings()
        XCTAssertEqual(settings.zcodeVersion, 5)
        XCTAssertTrue(settings.strict)
    }

    /// Reading settings that aren't a property list forgets the settings read before, so they aren't saved,
    /// but leaves the settings themselves as they were.
    func testAFailedReadForgetsWhatWasRead() throws {
        let settings = IFCompilerSettings()
        XCTAssertTrue(settings.restore(fromPlist: Data(settingsFile.utf8)))
        XCTAssertFalse(settings.restore(fromPlist: Data("not a property list".utf8)))
        XCTAssertEqual(settings.zcodeVersion, 8)

        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(
            from: try XCTUnwrap(settings.currentPlist), format: nil) as? [String: Any])
        XCTAssertNil(plist["IFWindowsSettings"])
        XCTAssertNotNil(plist["IFOutputSettings"])
    }

    // MARK: - Archiving

    /// The settings can be archived, though not securely.
    func testArchiving() throws {
        let settings = IFCompilerSettings()
        settings.zcodeVersion = 8
        settings.strict = false
        settings.compilerVersion = "6M62"

        let data = try NSKeyedArchiver.archivedData(withRootObject: settings, requiringSecureCoding: false)
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
        unarchiver.requiresSecureCoding = false
        let copy = try XCTUnwrap(unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? IFCompilerSettings)
        XCTAssertEqual(copy.zcodeVersion, 8)
        XCTAssertFalse(copy.strict)
        XCTAssertEqual(copy.compilerVersion, "6M62")
        XCTAssertNotNil(copy.setting(for: try settingsClass("IFMiscSettings")))
    }
}
