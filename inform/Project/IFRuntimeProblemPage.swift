//
//  IFRuntimeProblemPage.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFRuntimeProblemPage.h.
//

import Foundation

@objc @implementation extension IFRuntimeProblemPage {
    private final var errorURL: NSURL?
    private final var _markdownPath: String?

    init(problem error: String,
         inDirectory directory: String?,
         materialsDirectory: String?,
         internalDirectory: String) {
        if let directory = directory as NSString? {
            let errorFile = "\(error).md"
            if directory.starts(withCaseInsensitive: "Internal/") {
                // If directory starts with "Internal/" then resolve the path to inside the internal directory
                _markdownPath = ((internalDirectory as NSString).appendingPathComponent(directory.substring(from: 9)) as NSString).appendingPathComponent(errorFile)
            } else if directory.starts(withCaseInsensitive: "Materials/") {
                _markdownPath = materialsDirectory.map {
                    (($0 as NSString).appendingPathComponent(directory.substring(from: 10)) as NSString).appendingPathComponent(errorFile)
                }
            } else {
                // Otherwise the directory is given in full
                _markdownPath = directory.appendingPathComponent(errorFile)
            }
        } else {
            // If no directory is present, then redirect using old method (looks for a regular resource within the App).

            // The file that might contain the error
            var errorFile = "RTP_\(error)"

            // See if the file exists
            if Bundle.main.path(forResource: errorFile, ofType: "html") == nil {
                // The error file cannot be found: use a default
                NSLog("Warning: run-time error file '%@.html' not found, using RTP_Unknown.html instead", errorFile)
                errorFile = "RTP_Unknown"
            }

            // This URL is where the error file will reside
            errorURL = NSURL(string: "inform:/\(errorFile).html")
        }

        super.init()
    }

    var appPageURL: URL? {
        return errorURL as URL?
    }

    var markdownPath: String? {
        return _markdownPath
    }
}
