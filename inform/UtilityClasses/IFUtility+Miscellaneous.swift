//
//  IFUtility+Miscellaneous.swift
//  Inform
//
//  Created by Toby Nelson, 2014
//  Translated from Objective-C in November 2026. The interface is IFUtility (Miscellaneous) in IFUtility.h.
//

import AppKit
import UniformTypeIdentifiers

/// Made when it's first used, as Objective-C made it in +initialize
private let uniqueIdLock = NSLock()
private var uniqueId: UInt = 1000

// *******************************************************************************************
@objc(Miscellaneous) @implementation extension IFUtility {

    // MARK: - Generating unique IDs
    class func generateID() -> UInt {
        let new_id: UInt
        uniqueIdLock.lock()
        new_id = uniqueId
        uniqueId &+= 1
        uniqueIdLock.unlock()
        return new_id
    }

    class func contentTypes(forFilenameExtensions extensions: [String]) -> [UTType] {
        var types = [UTType]()
        for filenameExtension in extensions {
            if let type = UTType(filenameExtension: filenameExtension) {
                types.append(type)
            }
        }
        return types
    }

    // Save transcript (handles save dialog)
    @objc(saveTranscriptPanelWithString:window:)
    class func saveTranscriptPanel(with string: String,
                                   window: NSWindow) {

        let panel = NSSavePanel()

        panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["txt"])

        // Work out starting directory
        let prefString = UserDefaults.standard.object(forKey: "IFTranscriptURL") as? String
        var directoryURL = prefString.flatMap { URL(string: $0) }
        if directoryURL == nil {
            directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        }

        panel.directoryURL = directoryURL

        // Show it
        panel.beginSheetModal(for: window) { returnCode in
            if returnCode != .OK { return }

            // Remember the directory we last saved into
            if let writePrefString = panel.directoryURL?.absoluteString {
                UserDefaults.standard.set(writePrefString,
                                          forKey: "IFTranscriptURL")
            }

            // Save the data
            if let stringData = string.data(using: .utf8), let url = panel.url {
                try? stringData.write(to: url,
                                      options: .atomic)
            }
        }
    }

    // MARK: - Sandboxing
    @objc(sandboxed)
    class var isSandboxed: Bool {
        @objc(isSandboxed) get {
            let environ = ProcessInfo.processInfo.environment
            return environ["APP_SANDBOX_CONTAINER_ID"] != nil
        }
    }

    @objc(performSelector:object:)
    class func perform(_ selector: Selector, object: Any?) {
        if let object = object as? NSObject, object.responds(to: selector) {
            // ARC safe way to do performSelector (see http://stackoverflow.com/a/20058585/4786529 ) ...
            let imp = object.method(for: selector)
            typealias Function = @convention(c) (AnyObject, Selector) -> Void
            let function = unsafeBitCast(imp, to: Function.self)
            function(object, selector)
        }
    }

    class func adjustAttributesFontSize(_ dictionary: [NSAttributedString.Key: Any],
                                        size fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        var mutableResult = dictionary
        var font = mutableResult[.font] as? NSFont
        font = font?.withSize(fontSize)
        mutableResult[.font] = font
        return mutableResult
    }

    class func unzip(_ zipURL: URL, toDirectory targetDirectory: URL) -> Bool {
        // see https://stackoverflow.com/questions/2296667/unzipping-a-file-in-cocoa
        let fm = FileManager.default

        // create a new empty folder (to get a clean unzip)
        try? fm.createDirectory(at: targetDirectory,
                                withIntermediateDirectories: true,
                                attributes: nil)

        //now create an unzip task
        // -o overwrites existing files
        // -x ignores any *.DS_Store and __MACOSX detritus (Note the -x argument must appear after the zip file)
        let arguments = ["-o", zipURL.path, "-x", "*.DS_Store", "__MACOSX/*"]
        let unzipTask = Process()
        unzipTask.launchPath = "/usr/bin/unzip"
        unzipTask.currentDirectoryURL = targetDirectory
        unzipTask.arguments = arguments
        unzipTask.launch()
        unzipTask.waitUntilExit()

        if unzipTask.terminationStatus != 0 {
            return false
        }
        return true
    }
}
