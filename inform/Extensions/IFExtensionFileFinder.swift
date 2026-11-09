//
//  IFExtensionFileFinder.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFExtensionFileFinder.h.
//

import Foundation

@objc @implementation extension IFExtensionFileFinder {
    class func file(forExtension filename: String, extensionsManager: IFExtensionsManager) -> String? {
        // Get the author and extension name
        let components = (filename as NSString).pathComponents
        if components.count != 2 {
            if filename.hasPrefix("/") && FileManager.default.fileExists(atPath: filename) {
                return filename
            }
            return nil
        }

        let author = components[0]
        let extensionName = components[1]

        // Search for this extension
        let possibleExtensions = extensionsManager.filesInExtension(withName: author)
        if possibleExtensions.count <= 0 { return nil }

        for extnFile in possibleExtensions {
            if (extnFile as NSString).lastPathComponent.caseInsensitiveCompare(extensionName) == .orderedSame {
                // This is the extension file we need to open
                return extnFile
            }
        }

        return nil
    }
}
