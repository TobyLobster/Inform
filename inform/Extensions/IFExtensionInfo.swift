//
//  IFExtensionInfo.swift
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFExtensionInfo.h.
//

import Foundation

@objc @implementation
extension IFExtensionInfo {
    var displayName: String
    var filepath: String?
    var author: String
    /// The version (`nil` or empty if the extension has none)
    var version: String?
    var isBuiltIn: Bool

    init(displayName: String,
         filepath: String?,
         author: String,
         version: String?,
         isBuiltIn: Bool) {
        self.displayName = displayName
        self.filepath    = filepath
        self.author      = author
        self.version     = version
        self.isBuiltIn   = isBuiltIn
        super.init()
    }

    func caseInsensitiveCompare(_ b: IFExtensionInfo) -> ComparisonResult {
        var result = displayName.localizedCaseInsensitiveCompare(b.displayName)
        if result != .orderedSame {
            return result
        }
        result = author.localizedCaseInsensitiveCompare(b.author)
        if result != .orderedSame {
            return result
        }

        // As in Objective-C, no file is the same as any file, and a file comes after no file
        guard let filepath else {
            return .orderedSame
        }
        guard let otherFilepath = b.filepath else {
            return .orderedDescending
        }
        return (filepath as NSString).compare(otherFilepath)
    }

    class func canonicalTitle(_ displayName: String) -> String {
        // Remove any initial "The " from the name.
        var result = displayName as NSString
        let lowercased = result.lowercased as NSString
        if lowercased.starts(with: "the ") {
            result = result.substring(from: 4) as NSString
        } else if lowercased.starts(with: "a ") {
            result = result.substring(from: 2) as NSString
        } else if lowercased.starts(with: "an ") {
            result = result.substring(from: 3) as NSString
        }

        // Remove proviso in brackets
        if result.ends(with: ")") {
            // The name of the extension may be followed by a proviso in brackets: remove it
            let location = result.range(of: " (").location
            if location != NSNotFound && location > 1 {
                result = result.substring(to: location) as NSString
            }
        }
        return result as String
    }

    var safeVersion: String {
        guard let version else {
            return "Version (none)"
        }
        return version
    }

    var semver: IFSemVer {
        guard let version else {
            return IFSemVer()
        }

        let result = IFSemVer(string: version)
        return result
    }

    var isLiterate: Bool {
        guard let filepath else {
            return false
        }
        let file = filepath as NSString
        return file.lastPathComponent == "Contents.w" &&
               (file.deletingLastPathComponent as NSString).lastPathComponent == "Source"
    }

    var sourceFiles: [String] {
        guard let filepath else {
            return []
        }
        guard isLiterate else {
            return [filepath]
        }

        // The sections are the other .w files in the source folder and its folders, leaving out hidden ones
        let source = (filepath as NSString).deletingLastPathComponent
        guard let enumerator = FileManager.default.enumerator(atPath: source) else {
            return [filepath]
        }
        var sections: [String] = []
        for case let path as String in enumerator {
            let isFile = enumerator.fileAttributes?[.type] as? FileAttributeType == .typeRegular
            if isFile &&
               path != "Contents.w" &&
               (path as NSString).pathExtension.lowercased() == "w" &&
               !path.split(separator: "/").contains(where: { $0.hasPrefix(".") }) {
                sections.append(path)
            }
        }
        sections.sort { $0.caseInsensitiveCompare($1) == .orderedAscending }
        return [filepath] + sections.map { (source as NSString).appendingPathComponent($0) }
    }

    private final func stringEqual(_ string1: String?, to string2: String?) -> Bool {
        guard let string1, let string2 else {
            return string1 == string2
        }

        return (string1 as NSString).isEqual(to: string2)
    }

    public override func isEqual(_ other: Any?) -> Bool {
        guard let other = other as? NSObject else {
            return false
        }
        if other === self {
            return true
        }
        guard other.isKind(of: type(of: self)), let another = other as? IFExtensionInfo else {
            return false
        }

        if !stringEqual(displayName, to: another.displayName) {
            return false
        }
        if !stringEqual(filepath, to: another.filepath) {
            return false
        }
        if !stringEqual(author, to: another.author) {
            return false
        }
        if !stringEqual(version, to: another.version) {
            return false
        }
        if isBuiltIn != another.isBuiltIn {
            return false
        }
        return true
    }

    public override var hash: Int {
        return (displayName as NSString).hash
             ^ ((filepath as NSString?)?.hash ?? 0)
             ^ (author as NSString).hash
             ^ ((version as NSString?)?.hash ?? 0)
             ^ (isBuiltIn ? 1 : 0)
    }
}
