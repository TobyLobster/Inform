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
        XCTAssertEqual(settings.commandLineArguments.first, "-kE2SDwG")
        XCTAssertEqual(settings.commandLineArguments(forRelease: true, forTesting: false).first, "-kE2~S~DwG")

        // Testing always checks strictly, and with debugging
        settings.strict = false
        XCTAssertEqual(settings.commandLineArguments.first, "-kE2~SDwG")
        XCTAssertEqual(settings.commandLineArguments(forRelease: true, forTesting: true).first, "-kE2SDwG")

        settings.strict = true
        settings.infix = true
        settings.zcodeVersion = 8
        XCTAssertEqual(settings.commandLineArguments.first, "-kE2SXDwv8")
        XCTAssertEqual(settings.commandLineArguments(forRelease: true, forTesting: false).first, "-kE2~S~Dwv8")

        XCTAssertEqual(settings.commandLineArguments.last?.hasPrefix("+include_path="), true)
        XCTAssertEqual(settings.commandLineArguments.last?.hasSuffix(",.,../Source"), true)
    }

    /// A version of the Z-machine the compiler doesn't support is replaced by the default.
    func testUnsupportedStoryFormat() {
        let settings = IFCompilerSettings()
        settings.zcodeVersion = 2
        XCTAssertEqual(settings.commandLineArguments.first, "-kE2SDwv5")
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
}
