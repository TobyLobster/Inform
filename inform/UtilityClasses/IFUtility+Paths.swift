//
//  IFUtility+Paths.swift
//  Inform
//
//  Created by Toby Nelson, 2014
//  Translated from Objective-C in November 2026. The interface is IFUtility (Paths) in IFUtility.h.
//

import Foundation

/// A folder of the app's own in the temporary folder, made when it's first asked for
private let temporaryFolder: URL = {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString, isDirectory: true)
    try? FileManager.default.createDirectory(at: folder,
                                             withIntermediateDirectories: true,
                                             attributes: nil)
    return folder
}()

// *******************************************************************************************
@objc(Paths) @implementation extension IFUtility {

    // MARK: - Getting useful paths / URLs
    class func publicLibraryURL() -> URL? {
#if DEBUG
        let redirectFile = (NSHomeDirectory() as NSString).appendingPathComponent("redirect_inform.txt")
        if let redirection = (try? NSString(contentsOfFile: redirectFile, encoding: String.Encoding.utf8.rawValue))?.trimmingWhitespace,
           (redirection as NSString).length > 0 {
            return URL(string: redirection)
        }
#endif

        if IFPreferences.shared.publicLibraryDebug && !IFUtility.isSandboxed {
            var publicLibraryURLString: NSString
            publicLibraryURLString = (NSHomeDirectory() as NSString).appendingPathComponent("Documents") as NSString
            publicLibraryURLString = publicLibraryURLString.appendingPathComponent("InformPublicLibrary") as NSString
            publicLibraryURLString = publicLibraryURLString.appendingPathComponent("index.html") as NSString
            return URL(fileURLWithPath: publicLibraryURLString as String)
        }
        return URL(string: IFUtility.localizedString("PublicLibraryURL"))
    }

    class func pathForInformExternalAppSupport() -> String {
        // Get library directory (possibly in a sandboxed container).
        let newPath = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)[0]

        // Add inform subdirectory
        return (newPath as NSString).appendingPathComponent("Inform")
    }

    class func pathForInformExternalExtensions() -> String {
        return (pathForInformExternalAppSupport() as NSString).appendingPathComponent("Extensions")
    }

    class func pathForInformExternalLibraries() -> String {
        return (pathForInformExternalAppSupport() as NSString).appendingPathComponent("Libraries")
    }

    class func pathForInformExternalDocumentation() -> String {
        return (pathForInformExternalAppSupport() as NSString).appendingPathComponent("Documentation")
    }

    class func documentationPage(forExtensionTitled title: String,
                                 author: String,
                                 inMaterialsPath materialsPath: String) -> String? {
        let authorPath = ((((materialsPath as NSString).appendingPathComponent("Extensions") as NSString)
                                                       .appendingPathComponent("Reserved") as NSString)
                                                       .appendingPathComponent("Documentation") as NSString)
                                                       .appendingPathComponent(author)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: authorPath)) as NSArray?
        let folders = contents?.sortedArray(using: #selector(NSString.localizedStandardCompare(_:))) as? [String] ?? []

        // The folder is named after the title, followed by "-v" and the version if it has one
        // (e.g. "English Language-v10_2_0"). If there are several versions, use the latest.
        let versionPrefix = (title as NSString).appending("-v") as NSString
        var page: String? = nil
        for folder in folders as [NSString] {
            var matches = folder.isEqual(to: title)
            if !matches && folder.hasPrefix(versionPrefix as String) && folder.length > versionPrefix.length {
                let first = folder.character(at: versionPrefix.length)
                matches = (CharacterSet.decimalDigits as NSCharacterSet).characterIsMember(first)
            }
            if matches {
                let candidate = ((authorPath as NSString).appendingPathComponent(folder as String) as NSString)
                                                         .appendingPathComponent("index.html")
                if FileManager.default.fileExists(atPath: candidate) {
                    page = candidate
                }
            }
        }
        return page
    }

    // A version is nil only if the app has no InformCoreVersion.txt (see IFUtility+CompilerVersions.swift).

    class func path(forCompiler compilerVersion: String) -> String? {
        // Older versions of compiler
        if IFUtility.compilerVersion(compilerVersion, isNoLaterThan: "6M62") {
            guard let executablePath = (Bundle.main.executablePath as NSString?)?.deletingLastPathComponent,
                  let version = IFUtility.fullCompilerVersion(compilerVersion) else {
                return nil
            }
            return ((executablePath as NSString).appendingPathComponent(version) as NSString).appendingPathComponent("ni")
        }
        // Newer versions of compiler
        return IFUtility.path(forInformExecutable: "ni", version: compilerVersion)
    }

    class func path(forInformInternalAppSupport compilerVersion: String) -> String {
        // (An app always has a resource path)
        let resourcePath = (Bundle.main.resourcePath ?? "") as NSString
        if IFUtility.isLatestMajorMinorCompilerVersion(compilerVersion) {
            // If using external Inform Core 'Internal' data...
            if IFPreferences.shared.useExternalInformCoreDirectory {
                let informCore = IFPreferences.shared.externalInformCoreDirectory as NSString
                return (informCore.appendingPathComponent("inform7") as NSString).appendingPathComponent("Internal")
            }
            return resourcePath.appendingPathComponent("Internal")
        }
        let version = IFUtility.fullCompilerVersion(compilerVersion) ?? ""
        return (resourcePath.appendingPathComponent("retrospective") as NSString).appendingPathComponent(version)
    }

    class func path(forInformExecutable executableName: String, version compilerVersion: String) -> String? {
        if IFUtility.isLatestMajorMinorCompilerVersion(compilerVersion) {
            if IFPreferences.shared.useExternalInformCoreDirectory {
                // Use external locations for executables
                let informCore = IFPreferences.shared.externalInformCoreDirectory as NSString
                let name = executableName as NSString

                if name.isEqual(toStringCaseInsensitive: "ni") {
                    return informCore.appendingPathComponents("inform7/Tangled/inform7")
                }
                if name.isEqual(toStringCaseInsensitive: "inform7") {
                    return informCore.appendingPathComponents("inform7/Tangled/inform7")
                }
                if name.isEqual(toStringCaseInsensitive: "cBlorb") {
                    return informCore.appendingPathComponents("inblorb/Tangled/inblorb")
                }
                if name.isEqual(toStringCaseInsensitive: "inbuild") {
                    return informCore.appendingPathComponents("inbuild/Tangled/inbuild")
                }
                if name.isEqual(toStringCaseInsensitive: "inform6") {
                    return informCore.appendingPathComponents("inform6/Tangled/inform6")
                }
                if name.isEqual(toStringCaseInsensitive: "intest") {
                    // NOTE: This is outside the 'Inform Core' directory (alongside it)
                    return informCore.appendingPathComponents("../intest/Tangled/intest")
                }
                if name.isEqual(toStringCaseInsensitive: "glulxe") {
                    return informCore.appendingPathComponents("inform6/Tests/Assistants/dumb-glulx/glulxe/glulxe")
                }
                if name.isEqual(toStringCaseInsensitive: "dumb-frotz") {
                    return informCore.appendingPathComponents("inform6/Tests/Assistants/dumb-frotz/dumb-frotz")
                }

                // Anything else falls through...
            }
        }
        return Bundle.main.path(forAuxiliaryExecutable: executableName)
    }

    class func path(forInformInternalExtensions version: String) -> String {
        return (IFUtility.path(forInformInternalAppSupport: version) as NSString).appendingPathComponent("Extensions")
    }

    class func path(forInformInternalLibraries version: String) -> String {
        return (IFUtility.path(forInformInternalAppSupport: version) as NSString).appendingPathComponent("Libraries")
    }

    class func path(forInformInternalDocumentation version: String) -> String {
        return (IFUtility.path(forInformInternalAppSupport: version) as NSString).appendingPathComponent("Documentation")
    }

    class func temporaryDirectoryURL() -> URL {
        return temporaryFolder
    }
}
