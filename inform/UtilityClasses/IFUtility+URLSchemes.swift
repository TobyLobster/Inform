//
//  IFUtility+URLSchemes.swift
//  Inform
//
//  Created by Toby Nelson, 2014
//  Translated from Objective-C in November 2026. The interface is IFUtility (URLSchemes) in IFUtility.h.
//

import Foundation

// *******************************************************************************************
@objc(URLSchemes) @implementation extension IFUtility {

    /// The link after its scheme, percent-decoded. Nil if it isn't percent-encoded properly, which can't
    /// happen for an NSURL, as it encodes a stray % itself.
    private static func decodedPath(_ url: URL) -> String? {
        return (url as NSURL).resourceSpecifier?.removingPercentEncoding
    }

    private static func queryParametersFromURL(_ sourceURL: URL) -> [String: String] {
        var results = [String: String]()

        guard let path = decodedPath(sourceURL) else { return results }
        var query = path.components(separatedBy: "?")
        if query.count < 2 {
            return results
        }
        query = query[1].components(separatedBy: "#")

        let keyValues = query[0].components(separatedBy: "=")

        var i = 0
        while i < (keyValues.count - 1) {
            results[keyValues[i]] = keyValues[i + 1]
            i += 2
        }
        return results
    }

    private static func fragmentFromURL(_ sourceURL: URL) -> String {
        guard let path = decodedPath(sourceURL) else { return "" }
        let array = path.components(separatedBy: "#")
        if array.count < 2 {
            return ""
        }
        return array[1]
    }

    private static func heirarchyFromURL(_ sourceURL: URL) -> String? {
        guard let path = decodedPath(sourceURL) as NSString? else { return nil }
        let query  = path.index(of: "?")
        let hash   = path.index(of: "#")
        var result = path.length
        if query != NSNotFound { result = min(result, query) }
        if hash  != NSNotFound { result = min(result, hash) }

        return path.substring(to: result)
    }

    class func decodeSourceSchemeURL(_ sourceURL: URL) -> [Any]? {
        let path = decodedPath(sourceURL)

        // Get line number from fragment
        let fragment = fragmentFromURL(sourceURL) as NSString
        if fragment.length == 0 {
            NSLog("Bad source URL, no fragment: %@", path ?? "(null)")
            return nil
        }

        // sourceLine can have format 'line10' or '10'. 'line10' is more likely
        var lineNumber = fragment.intValue

        if lineNumber == 0 && fragment.hasPrefix("line") {
            lineNumber = (fragment.substring(from: 4) as NSString).intValue
        }

        // Get source filename
        guard let sourceFile = heirarchyFromURL(sourceURL) else {
            return nil
        }

        // Get test case from query parameters
        let parameters = queryParametersFromURL(sourceURL)
        let testCase = parameters["case"] ?? ""

        return [sourceFile, testCase, NSNumber(value: lineNumber)]
    }

    class func decodeSkeinSchemeURL(_ skeinURL: URL) -> [String]? {
        // e.g: Input 'skein:1003?case=B' returns [B,1003]

        guard let scheme = skeinURL.scheme, (scheme as NSString).isEqual(toStringCaseInsensitive: "skein") else {
            return nil
        }

        // Get node id from heirarchy. (Objective-C raised an exception when there was none.)
        guard let nodeIdString = heirarchyFromURL(skeinURL) else {
            return nil
        }

        // Get test case from query parameters
        let parameters = queryParametersFromURL(skeinURL)
        let testCase = parameters["case"] ?? ""

        return [testCase, nodeIdString]
    }
}
