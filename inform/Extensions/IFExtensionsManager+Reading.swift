//
//  IFExtensionsManager+Reading.swift
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is IFExtensionsManager (Reading) in IFExtensionsManager.h.
//

import Foundation

// *******************************************************************************************
@objc(Reading) @implementation
extension IFExtensionsManager {

    // Work out the extension's author, title and version by reading the first line from a given full filepath of a Natural Inform extension file
    func info(forNaturalInformExtension file: String,
              author authorOut: UnsafeMutablePointer<NSString?>?,
              title titleOut: UnsafeMutablePointer<NSString?>?,
              version versionOut: UnsafeMutablePointer<NSString?>?) -> IFExtensionResult {
        let mgr = FileManager.default

        authorOut?.pointee = nil
        titleOut?.pointee = nil
        versionOut?.pointee = nil

        // Can't do anything with a non-existant file
        var isDir: ObjCBool = false
        let exists = mgr.fileExists(atPath: file,
                                    isDirectory: &isDir)
        if !exists || isDir.boolValue {
            return .notFound
        }

        // Read the first 1k of the extension
        let extensionFile = FileHandle(forReadingAtPath: file)
        let extensionInitialData = extensionFile?.readData(ofLength: 1024) ?? Data()
        var readString = NSString(data: extensionInitialData,
                                  encoding: String.Encoding.utf8.rawValue)
        // The data read can end part way through a character: if so, leave that character out
        var cut = 1
        while readString == nil && cut <= 3 && cut < extensionInitialData.count {
            readString = NSString(data: extensionInitialData.subdata(in: 0..<(extensionInitialData.count - cut)),
                                  encoding: String.Encoding.utf8.rawValue)
            cut += 1
        }
        guard var extensionString = readString else {
            return .notValid
        }

        // Fix line endings
        if extensionString.range(of: "\r").location != NSNotFound {
            extensionString = extensionString.replacingOccurrences(of: "\r\n", with: "\n") as NSString
            extensionString = extensionString.replacingOccurrences(of: "\r", with: "\n") as NSString
        }

        // Get the first line
        let range = extensionString.range(of: "\n")
        if range.location != NSNotFound {
            extensionString = extensionString.substring(to: range.location) as NSString
        }

        // Trim whitespace
        extensionString = extensionString.trimmingCharacters(in: .whitespaces) as NSString

        // Check that the ending is 'begins here'
        if !(extensionString.lowercased as NSString).ends(with: " begins here.") {
            return .notValid
        }

        // Remove the " begins here." from the end
        extensionString = extensionString.substring(to: extensionString.length - (" begins here." as NSString).length) as NSString

        // Examples:
        // Version 1 of Title Name by Author Name
        // Another Title Name by Author Name

        // Find version name
        var versionName: NSString? = nil
        if (extensionString.lowercased as NSString).starts(with: "version ") {
            let versionRange = extensionString.range(of: " of ",
                                                     options: .caseInsensitive)
            // Without an ' of ', 'Version' is part of the title
            if versionRange.location != NSNotFound {
                versionName     = extensionString.substring(to: versionRange.location) as NSString

                // Remove the version
                extensionString = extensionString.substring(from: versionRange.location + versionRange.length) as NSString
            }
        }

        // Find title name
        var titleName: NSString
        do {
            let byPosition = extensionString.range(of: " by ",
                                                   options: .caseInsensitive)
            // Must have a ' by '
            if byPosition.location == NSNotFound {
                return .notValid
            }

            titleName = extensionString.substring(to: byPosition.location) as NSString

            // Remove the title
            extensionString = extensionString.substring(from: byPosition.location + byPosition.length) as NSString
        }

        // Remainder of string is the author
        var authorName = extensionString

        authorName  = authorName.trimmingWhitespace as NSString
        titleName   = titleName.trimmingWhitespace as NSString
        versionName = versionName?.trimmingWhitespace as NSString?

        // Remove leading 'The' from extension name
        if (titleName.lowercased as NSString).starts(with: "the ") {
            titleName = titleName.substring(from: ("the " as NSString).length) as NSString
        }

        // Bail out if there is no author name or title left
        if authorName.length == 0 ||
           titleName.length  == 0 {
            return .notValid
        }

        authorOut?.pointee = authorName
        titleOut?.pointee = titleName
        versionOut?.pointee = versionName
        return .success
    }

    func parseExtensionsList(_ jsonString: String?) -> NSMutableArray {
        let result = NSMutableArray()

        guard let jsonString, let jsonData = jsonString.data(using: .utf8) else {
            // There's no census to read
            return result
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: jsonData,
                                                      options: [])
        } catch {
            // JSON was malformed
            NSLog("Warning: Inbuild JSON error: %@", (error as NSError).description)
            NSLog("JSON was: %@", jsonString)
            return result
        }

        // The top level is a dictionary. We are only interested in key "inspection".
        if let results = object as? [String: Any] {
            if let inspection = results["inspection"] as? [Any] {
                for entryObject in inspection {
                    guard let entry = entryObject as? [String: Any] else {
                        continue
                    }
                    guard let resource = entry["resource"] as? [String: Any] else {
                        continue
                    }

                    guard let type = resource["type"] as? NSString,
                          type.isEqual(toStringCaseInsensitive: "extension") else {
                        continue
                    }

                    let title = resource["title"] as? String ?? ""
                    let author = resource["author"] as? String ?? ""
                    var version = resource["version"] as? String ?? ""
                    if (version as NSString).length > 0 {
                        version = "v" + version
                    }

                    // An extension that's a folder (.i7xd, Inform 10's usual form) is given by its folder,
                    // and its file is the one inbuild reads. One with no file to open or search is left out.
                    guard let fullFilepath = entry["location-file"] as? String ??
                            (entry["location-directory"] as? String).flatMap({ sourceFile(ofFolderExtension: $0, title: title) }) else {
                        continue
                    }

                    let info = IFExtensionInfo(displayName: title,
                                               filepath: fullFilepath,
                                               author: author,
                                               version: version,
                                               isBuiltIn: false)
                    result.add(info)
                }
            }
        }

        return result
    }
}

/// The file that inbuild reads an extension that's a folder from, worked out as inbuild's
/// `Extensions::main_source_file` and `Extensions::alternative_source_file` do: `Source/<title>.i7x`,
/// or else `Source/Contents.w` (a literate extension, whose sections are in the same folder), or else
/// the first `.i7x` file in `Source`, by name without case mattering. Hidden files, such as those
/// macOS leaves on other volumes, aren't taken.
private func sourceFile(ofFolderExtension folder: String, title: String) -> String? {
    let fileManager = FileManager.default
    let source = (folder as NSString).appendingPathComponent("Source")

    func isFile(_ name: String) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: (source as NSString).appendingPathComponent(name), isDirectory: &isDir) &&
               !isDir.boolValue
    }

    for name in [title + ".i7x", "Contents.w"] where isFile(name) {
        return (source as NSString).appendingPathComponent(name)
    }

    let names = (try? fileManager.contentsOfDirectory(atPath: source)) ?? []
    let sourceFiles = names.filter { !$0.hasPrefix(".") && ($0 as NSString).pathExtension.lowercased() == "i7x" && isFile($0) }
    guard let first = sourceFiles.min(by: { $0.caseInsensitiveCompare($1) == .orderedAscending }) else {
        return nil
    }
    return (source as NSString).appendingPathComponent(first)
}

// *******************************************************************************************
// NSOpenSavePanelDelegate, which IFExtensionsManager.h says the manager conforms to
extension IFExtensionsManager {

    // MARK: - NSSavePanel delegate methods

    /// Whether the open panel offers a file: folders, and files that might be extensions
    @objc(panel:shouldEnableURL:)
    public func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path,
                                                    isDirectory: &isDir)

        if !exists {
            return false
        }
        if isDir.boolValue {
            return true
        }

        let extn = url.pathExtension.lowercased()

        if extn != "i7x" &&
           extn != "" {
            return false
        }

        return true
    }
}
