//
//  IFUtility+CompilerVersions.swift
//  Inform
//
//  Created by Toby Nelson, 2014
//  Translated from Objective-C in November 2026. The interface is IFUtility (CompilerVersions) in IFUtility.h.
//

import Foundation

/// The build takes this from the app's ni (see compiler_injection.sh)
private let bundledCoreBuildVersion: String? = {
    guard let path = Bundle.main.path(forResource: "InformCoreVersion", ofType: "txt") else {
        return nil
    }
    return (try? String(contentsOfFile: path, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
}()

private extension NSString {
    /// Without any trailing ".0"s
    var shortenedVersionNumberString: String {
        let unnecessaryVersionSuffix = ".0"
        var shortenedVersionNumber = self

        while shortenedVersionNumber.hasSuffix(unnecessaryVersionSuffix) {
            shortenedVersionNumber = shortenedVersionNumber.substring(to: shortenedVersionNumber.length - (unnecessaryVersionSuffix as NSString).length) as NSString
        }

        return shortenedVersionNumber as String
    }
}

// *******************************************************************************************
@objc(CompilerVersions) @implementation extension IFUtility {

    // A version is nil only if the app has no InformCoreVersion.txt, and then these give what
    // messages to nil gave in Objective-C.

    class func isLatestMajorMinorCompilerVersion(_ compilerVersion: String) -> Bool {
        guard let version = fullCompilerVersion(compilerVersion) as NSString? else {
            return false
        }
        let currentVersion = coreBuildVersion

        // If version wanted is equal to the current version, use the current version
        if let currentVersion = currentVersion, version.isEqual(toStringCaseInsensitive: currentVersion) {
            return true
        }
        // If version wanted is equal to the 'major.minor' of the current version, good enough, use the current version
        if let currentVersion = currentVersion, version.isEqual(to: majorMinor(currentVersion)) {
            return true
        }
        // There's no retrospective build of 10.1, so it uses the current version (as on Windows)
        if version.isEqual(to: "10.1") {
            return true
        }
        return false
    }

    class func compilerVersion(_ compilerVersion: String, isAfter afterVersion: String) -> Bool {
        return compilerVersionCompare(compilerVersion, other: afterVersion) == .orderedDescending
    }

    class func compilerVersion(_ compilerVersion: String, isNoLaterThan otherVersion: String) -> Bool {
        return !self.compilerVersion(compilerVersion, isAfter: otherVersion)
    }

    class func fullCompilerVersion(_ version: String) -> String? {
        if (version as NSString).isEqual(toStringCaseInsensitive: "") ||
           (version as NSString).isEqual(toStringCaseInsensitive: "****") {
            return coreBuildVersion
        }
        return version
    }

    class func compilerVersionCompare(_ version1: String, other version2: String) -> ComparisonResult {
        let version1 = fullCompilerVersion(version1) as NSString?
        let version2 = fullCompilerVersion(version2) as NSString?

        let isV1Dotted = version1?.containsSubstring(".") ?? false
        let isV2Dotted = version2?.containsSubstring(".") ?? false

        // One version is dotted, the other not
        if isV1Dotted != isV2Dotted {
            if isV1Dotted {
                return .orderedDescending
            }
            return .orderedAscending
        }

        if isV1Dotted, let version1 = version1, let version2 = version2 {
            // Both versions are dotted, we use numerical search compare after removing any trailing ".0"s so that "1" = "1.0" = "1.0.0"
            return (version1.shortenedVersionNumberString as NSString).compare(version2.shortenedVersionNumberString, options: .numeric)
        }

        // Neither version is dotted, use regular string compare
        guard let version1 = version1 else { return .orderedSame }
        guard let version2 = version2 else { return .orderedDescending }
        return version1.compare(version2 as String, options: .caseInsensitive)
    }

    class func compilerFormatParameterName(_ version: String) -> String {
        let result = compilerVersionCompare(version, other: "6L02")

        if result != .orderedDescending {
            // Old
            return "extension"
        }
        // New
        return "format"
    }

    class func compilerProjectParameterName(_ version: String) -> String {
        let result = compilerVersionCompare(version, other: "6L02")

        if result != .orderedDescending {
            // Old
            return "package"
        }
        // New
        return "project"
    }

    class var coreBuildVersion: String? {
        return bundledCoreBuildVersion
    }

    class func majorMinor(_ version: String) -> String {
        let array = (version as NSString).components(separatedBy: ".")
        if array.count >= 3 {
            return "\(array[0]).\(array[1])"
        }
        return version
    }
}
