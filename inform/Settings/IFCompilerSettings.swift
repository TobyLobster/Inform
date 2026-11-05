//
//  IFCompilerSettings.swift
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFCompilerSettings.h, and
//  the constants are defined in IFCompilerSettingsConstants.m.
//

//
// We've got a bit of an evolutionary thing going on here. Originally, this was going to be the
// repository of all settings. Back in those days, Inform.app was just a front-end for the Inform 6
// compiler and didn't really do anything fancy. Now, I've redesigned things so that we can have
// 'IFSetting' objects: these are controller objects for individual sets of settings, and can have
// their own store. But we've still got this object, which acts as the interface to the compiler itself,
// so the 'older' settings are stored here and not as part of the new settings system.
//
// At some point, the settings that are here should probably be moved into their respective IFSetting
// objects, but for the moment, they will remain.
//

import Foundation

// == Possible locations for the library ==
private let libraryPaths: [String] = {
    var res: [String] = []

    // User-supplied library directories
    res.append(IFUtility.pathForInformExternalLibraries())

    // Internal library directories
    // (An app always has a resource path)
    let bundlePath = (Bundle.main.resourcePath ?? "") as NSString
    res.append(bundlePath.appendingPathComponent("Library"))

    return res
}()

//
// Settings are read from a property list, so a setting's value is read as `AnyObject`, and asked for
// its `boolValue` or `intValue` as Objective-C did: a string answers as a number does.
//

@objc @implementation extension IFCompilerSettings {

    /// (DEPRECATED) Maps keys to settings
    private final var store: NSMutableDictionary? = nil
    /// \c IFSetting object that deals with specific settings areas
    private final var genericSettings: [IFSetting] = []

    /// The PList we loaded to construct this object (used if there's some settings in the plist that aren't handled)
    private final var originalPlist: NSDictionary? = nil

    class var inform6LibraryPaths: [String] {
        return libraryPaths
    }

    class func path(forLibrary library: String) -> String? {
        let searchPaths = self.inform6LibraryPaths

        for path in searchPaths {
            var libDir = (path as NSString).appendingPathComponent(library)
            var isDir: ObjCBool = false

            if FileManager.default.fileExists(atPath: libDir, isDirectory: &isDir) {
                if !isDir.boolValue {
                    // Should be a file containing the actual library directory
                    // (We do this because we can't rely on the finder to reliably copy
                    // symbolic links)
                    // Must be a directory
                    let newDir: String
                    do {
                        newDir = try String(contentsOfFile: libDir, encoding: .utf8)
                    } catch {
                        NSLog("Couldn't read library link %@ in %@: %@", library, path, error as NSError)
                        continue
                    }

                    libDir = (path as NSString).appendingPathComponent(newDir)

                    if !FileManager.default.fileExists(atPath: libDir, isDirectory: &isDir) {
                        NSLog("Couldn't find library link (%@) from %@ in %@", newDir, library, path)
                        continue
                    }
                    if !isDir.boolValue {
                        NSLog("Library link to %@ not a directory in %@", newDir, path)
                        continue
                    }
                }

                return libDir
            }
        }

        return nil
    }

    class var availableLibraries: [String] {
        var result: [String] = []
        let paths = self.inform6LibraryPaths

        for path in paths {
            let libraryDirectory = (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []

            for lib in libraryDirectory {
                if !result.contains(lib) {
                    result.append(lib)
                }
            }
        }

        return result
    }

    // == Initialisation ==
    override init() {
        super.init()

        store = NSMutableDictionary()

        // Default settings
        usingNaturalInform = false

        genericSettings = IFSettingsController.makeStandardSettings() as! [IFSetting]

        for setting in genericSettings {
            setting.compilerSettings = self
        }
    }

    deinit {
        for setting in genericSettings {
            setting.compilerSettings = nil
        }
    }

    // MARK: - Getting information on what is going on

    var primaryCompilerType: String {
        if usingNaturalInform {
            return IFCompilerNaturalInform
        } else {
            return IFCompilerInform6
        }
    }

    // == The command line ==
    func commandLineArguments(forRelease release: Bool, forTesting testing: Bool) -> [String] {
        var result: [String] = []

        // Switches
        var switches = "-"
        switches += "k"
        switches += "E2"

        if (strict && !release) || testing {
            switches += "S"
        } else {
            switches += "~S"
        }

        if infix && !release {
            switches += "X"
        } else {
            // Off by default
        }

        if (debug && !release) || testing {
            switches += "D"
        } else {
            switches += "~D"
        }

        if usingNaturalInform {
            // Disable warnings when compiling with Natural Inform
            switches += "w"
        }

        // Select a zcode version
        let supportedZCodeVersions = supportedZMachines
        var zcVersion = zcodeVersion

        if !supportedZCodeVersions.contains(NSNumber(value: zcVersion)) {
            // Use default version
            zcVersion = supportedZCodeVersions[0].int32Value
        }

        if zcVersion < 255 {
            // ZCode
            switches += "v\(zcVersion)"
        } else {
            // Glulx
            switches += "G"
        }

        result.append(switches)

        // Paths
        var includePath: [String] = []

        // User-defined includes

        // Library directory
        var libPath = type(of: self).path(forLibrary: "Natural")      // TODO: Not sure this is needed
        if libPath == nil { libPath = type(of: self).path(forLibrary: "Standard") }
        if libPath == nil { libPath = type(of: self).path(forLibrary: type(of: self).availableLibraries[0]) }

        var isDir: ObjCBool = false
        if let path = libPath, !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            // IMPLEMENT ME: try user preferences file
            libPath = nil
        }

        if let libPath {
            includePath.append(libPath)
        }

        // Current directory and source directory
        includePath.append(".")
        includePath.append("../Source")

        // Finish up paths

        var incString = "+include_path="
        var comma = false

        for path in includePath {
            if comma { incString += "," }
            incString += path
            comma = true
        }

        result.append(incString)

        return result
    }

    var inform6CompilerToUse: String? {
        return IFUtility.path(forInformExecutable: "inform6", version: compilerVersion)
    }

    var supportedZMachines: [NSNumber] {
        return [5, 3, 4, 6, 7, 8, 256]
    }

    func isNaturalInformCompilerPathValid() -> Bool {
        guard let path = naturalInformCompilerToUse else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    var naturalInformCompilerToUse: String? {
        if !usingNaturalInform {
            return nil
        }

        return IFUtility.path(forCompiler: compilerVersion)
    }

    var naturalInformCommandLineArguments: [String] {
        var res: [String] = []

        let version: String = compilerVersion
        let result = IFUtility.compilerVersionCompare(version, other: "6L02")

        if result == .orderedAscending {
            // Very old
            let internalPath = IFUtility.path(forInformInternalAppSupport: version)
            res.append("-rules")
            res.append((internalPath as NSString).appendingPathComponent("Extensions"))

            res.append("-log")
        } else if result == .orderedSame {
            // Fairly old
            let externalPath = IFUtility.pathForInformExternalAppSupport()
            res.append("-extensions")
            res.append((externalPath as NSString).appendingPathComponent("Extensions"))

            let internalPath = IFUtility.path(forInformInternalAppSupport: version)
            res.append("-rules")
            res.append((internalPath as NSString).appendingPathComponent("Extensions"))

            res.append("-log")
        } else {
            // New
            let internalPath = IFUtility.path(forInformInternalAppSupport: version)
            res.append("-internal")
            res.append(internalPath)

            if allowLegacyExtensionDirectory {
                let externalPath = IFUtility.pathForInformExternalAppSupport()
                res.append("-deprecated-external")
                res.append(externalPath)
            }
        }

        return res
    }

    // MARK: - Setting up the settings

    // Originally, there was only this object for dealing with settings, which did not require the
    // structured approach we're now using. Using these routines is deprecated: use a settings controller
    // instead where possible.

    func settingsHaveChanged() {
        NotificationCenter.default.post(name: .IFSetting, object: self)
    }

    var usingNaturalInform: Bool {
        get {
            return true
        }
        set {
            // Projects are always Inform 7 now
        }
    }

    var strict: Bool {
        get {
            let setting = dictionary(for: IFMiscSettings.self)[IFSettingStrict] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return true
            }
        }
        set {
            dictionary(for: IFMiscSettings.self)[IFSettingStrict] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    var infix: Bool {
        get {
            let setting = dictionary(for: IFMiscSettings.self)[IFSettingInfix] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return false
            }
        }
        set {
            dictionary(for: IFMiscSettings.self)[IFSettingInfix] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    private final var debug: Bool {
        let setting = dictionary(for: IFMiscSettings.self)[IFSettingDEBUG] as AnyObject?

        if let setting {
            return setting.boolValue!
        } else {
            return true
        }
    }

    var nobbleRng: Bool {
        get {
            let setting = dictionary(for: IFOutputSettings.self)[IFSettingNobbleRng] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return false
            }
        }
        set {
            dictionary(for: IFOutputSettings.self)[IFSettingNobbleRng] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    var basicInform: Bool {
        get {
            let setting = dictionary(for: IFOutputSettings.self)[IFSettingBasicInform] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return false
            }
        }
        set {
            dictionary(for: IFOutputSettings.self)[IFSettingBasicInform] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    var compilerVersion: String! {
        get {
            // (A value that isn't a string is taken as no version: Objective-C returned it as one)
            let setting = dictionary(for: IFOutputSettings.self)[IFSettingCompilerVersion] as? String

            if let setting {
                return setting
            } else {
                return ""
            }
        }
        set {
            dictionary(for: IFOutputSettings.self)[IFSettingCompilerVersion] = newValue
            settingsHaveChanged()
        }
    }

    var allowLegacyExtensionDirectory: Bool {
        get {
            let setting = dictionary(for: IFAdvancedSettings.self)[IFSettingAllowLegacyExtensionDirectory] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                // Allow legacy extensions by default. New projects set this to NO.
                return true
            }
        }
        set {
            dictionary(for: IFAdvancedSettings.self)[IFSettingAllowLegacyExtensionDirectory] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    var zcodeVersion: Int32 {
        get {
            let setting = dictionary(for: IFOutputSettings.self)[IFSettingZCodeVersion] as AnyObject?

            if let setting {
                return setting.intValue!
            } else {
                return 256
            }
        }
        // (The header names the setter, which Swift doesn't take from it)
        @objc(setZCodeVersion:) set {
            dictionary(for: IFOutputSettings.self)[IFSettingZCodeVersion] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    var testingTabHelpShown: Bool {
        get {
            let setting = dictionary(for: IFMiscSettings.self)[IFSettingTestingTabHelpShown] as AnyObject?

            if let setting {
                return setting.boolValue!
            } else {
                return true
            }
        }
        set {
            if newValue != testingTabHelpShown {
                dictionary(for: IFMiscSettings.self)[IFSettingTestingTabHelpShown] = NSNumber(value: newValue)
                settingsHaveChanged()
            }
        }
    }

    var testingTabShownCount: Int32 {
        get {
            let setting = dictionary(for: IFMiscSettings.self)[IFSettingTestingTabShownCount] as AnyObject?

            if let setting {
                return setting.intValue!
            } else {
                return 0
            }
        }
        set {
            dictionary(for: IFMiscSettings.self)[IFSettingTestingTabShownCount] = NSNumber(value: newValue)
            settingsHaveChanged()
        }
    }

    var fileExtension: String {
        let version = zcodeVersion

        if version == 256 { return "ulx" }
        return "z\(version)"
    }

    // MARK: - Generic settings

    @objc(setGenericSettings:)
    func setGeneric(_ newGenericSettings: [IFSetting]) {
        genericSettings = newGenericSettings
    }

    @objc(dictionaryForClass:)
    func dictionary(for cls: AnyClass) -> NSMutableDictionary {
        let name = NSStringFromClass(cls)
        var dict = store?[name] as? NSMutableDictionary

        if dict == nil {
            dict = NSMutableDictionary()

            store?[name] = dict
        }

        return dict!
    }

    @objc(settingForClass:)
    func setting(for cls: AnyClass) -> IFSetting? {
        for setting in genericSettings {
            if NSStringFromClass(type(of: setting)) == NSStringFromClass(cls) {
                return setting
            }
        }

        return nil
    }

    // MARK: - NSCoding

    @objc(encodeWithCoder:)
    func encode(with encoder: NSCoder) {
        encoder.encode(store)
    }

    public required convenience init?(coder decoder: NSCoder) {
        self.init() // Call the designated initialiser first

        store = decoder.decodeObject() as? NSMutableDictionary

        // Convert from the old format to the new format -- not done yet (do we really need this?)
    }

    // MARK: - Property lists

    var currentPlist: Data? {
        // Use the original plist as a template if it exists (this will preserve any plist data that
        // say, the Windows version might produce)
        let plData: NSMutableDictionary

        if let originalPlist {
            plData = originalPlist.mutableCopy() as! NSMutableDictionary
        } else {
            plData = NSMutableDictionary()
        }

        // Get updated data from all the generic settings classes
        for setting in genericSettings {
            // (Read through Objective-C, which gives the setting's own dictionary, where Swift would copy it)
            if let entries = setting.value(forKey: "plistEntries") {
                plData[NSStringFromClass(type(of: setting))] = entries
            }
        }

        // Update the original list to reflect the current one
        originalPlist = plData.copy() as? NSDictionary

        // Create the actual plist
        let res: Data?
        do {
            res = try PropertyListSerialization.data(fromPropertyList: plData, format: .xml, options: 0)
        } catch {
            NSLog("Couldn't create settings data: %@", error as NSError)
            NSLog("Settings data was: %@", plData)
            res = nil
        }

        // Finish up
        return res
    }

    @objc(reloadSettingsForClass:)
    func reload(forClass className: String) {
        var settingToReload: IFSetting? = nil

        // Find the setting corresponding to the supplied class
        for settingToTest in genericSettings {
            if NSStringFromClass(type(of: settingToTest)) == className {
                settingToReload = settingToTest
                break
            }
        }

        // If it exists, get it to update from the plist data
        if let settingToReload {
            // Anything but a dictionary can't be read: pass it over
            let settingData = originalPlist?[className] as? [String: Any]

            settingToReload.update(self, withPlistEntries: settingData)
        }
    }

    func reloadAllSettings() {
        if let originalPlist {
            // Load the setting data from the plist
            for (key, _) in originalPlist {
                reload(forClass: key as! String)
            }
        }
    }

    @objc(restoreSettingsFromPlist:)
    func restore(fromPlist plData: Data) -> Bool {
        // This new data will replace the original data (even if the parsing fails)
        originalPlist = nil

        // Parse the plist into a dictionary
        var fmt = PropertyListSerialization.PropertyListFormat.xml
        let parsed: Any
        do {
            parsed = try PropertyListSerialization.propertyList(from: plData,
                                                                options: .mutableContainersAndLeaves,
                                                                format: &fmt)
        } catch {
            NSLog("Failed to load settings: %@", error as NSError)
            return false
        }
        guard let plist = parsed as? NSDictionary else {
            NSLog("Failed to load settings: property list is not a dictionary")
            return false
        }

        // Store as the 'original' plist
        originalPlist = plist.copy() as? NSDictionary

        // Load the plist into the various property items
        for (key, _) in plist {
            reload(forClass: key as! String)
        }

        return true
    }
}
