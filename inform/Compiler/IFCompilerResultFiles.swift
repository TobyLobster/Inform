//
//  IFCompilerResultFiles.swift
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFCompilerResultFiles.h.
//

import Foundation

@objc @implementation extension IFCompilerResultFiles {
    class func tabId(forFile theFile: String) -> IFCompilerTabId {
        /// Fixed dictionary of document names and their tabs
        let tabDictionary: [String: IFCompilerTabId] = ["debug log.txt":         .tabDebugging,
                                                        "auto.inf":              .tabInform6,
                                                        "problems.html":         .tabReport,
                                                        "log of problems.txt":   .tabReport,
                                                        "inbuild.html":          .tabInBuild,
                                                        "compiler":              .tabConsole]

        let lowerFile = theFile.lowercased()

        guard let tabId = tabDictionary[lowerFile] else {
            return .tabInvalid
        }
        return tabId
    }

    class func filesToShow(of files: [String], showDebuggingLogs: Bool, problemsURL lastProblemURL: URL?) -> [String] {
        // The set of files we should avoid showing
        var excludedFiles = Set<String>()

        if !showDebuggingLogs {
            excludedFiles.insert("debug log.txt")
            excludedFiles.insert("auto.inf")
        }

        var excludedFilename: String? = nil
        if let lastProblemURL {
            excludedFilename = ((lastProblemURL.path as NSString).lastPathComponent as NSString).deletingPathExtension.lowercased()
        }

        var filesToShow: [String] = []

        // Enumerate across the list of files
        for key in files {
            let type = (key as NSString).pathExtension.lowercased()

            // Skip this file if it's in the excluded list
            if excludedFiles.contains(key.lowercased()) { continue }

            // HTML, text and inf files go in a tab view showing various different status messages
            // With NI, the problems file is most important: we substitute this if the compiler wants
            let filename = (key as NSString).deletingPathExtension.lowercased()

            let tempFile = ((key as NSString).length >= 4) && ((key as NSString).substring(to: 4).lowercased() == "temp")
            let goodFileType = type == "inf" ||
                               type == "txt" ||
                               type == "html" ||
                               type == "htm"
            let excludedFile = (lastProblemURL != nil) && (filename == "problems" || filename == excludedFilename)

            if !tempFile && !excludedFile && goodFileType {
                filesToShow.append(key)
            }
        }

        return filesToShow
    }
}
