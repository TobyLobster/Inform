//
//  IFSingleFile.swift
//  Inform
//
//  Created by Andrew Hunter on 23/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFSingleFile.h.
//

import Cocoa

@objc @implementation extension IFSingleFile {
    /// The contents of the file
    private final var fileStorage: NSTextStorage
    /// The encoding used for the file (a String.Encoding raw value)
    private final var fileEncoding: UInt

    var initialSelectionRange: NSRange

    // MARK: - Initialisation

    public override init() {
        fileStorage = NSTextStorage()
        fileEncoding = String.Encoding.utf8.rawValue
        initialSelectionRange = NSRange(location: 0, length: 0)
        super.init()
    }

    deinit {
        IFSyntaxManager.unregisterTextStorage(fileStorage)
    }

    // MARK: - Data

    public override func makeWindowControllers() {
        let aController = IFSingleController(initialSelectionRange: initialSelectionRange)
        addWindowController(aController)
    }

    public override func data(ofType type: String) throws -> Data {
        guard let data = (fileStorage.string as NSString).data(using: fileEncoding) else {
            // The text has characters the file's encoding can't hold
            throw NSError(domain: NSCocoaErrorDomain,
                          code: NSFileWriteInapplicableStringEncodingError,
                          userInfo: [NSStringEncodingErrorKey: fileEncoding])
        }
        return data
    }

    public override func read(from data: Data, ofType type: String) throws {
        var highlightType: IFHighlightType = .none
        var intel: IFSyntaxIntelligence? = nil

        fileEncoding = String.Encoding.utf8.rawValue

        //
        // Use the appropriate highlighter, intelligence and encoding, based on the file type
        //
        switch IFProjectTypes.fileType(from: type) {
        case .inform6ICLFile:
            // No highlighter currently available for ICL files, and they're latin-1
            fileEncoding = String.Encoding.isoLatin1.rawValue
        case .inform6SourceFile:
            fileEncoding = String.Encoding.isoLatin1.rawValue
            highlightType = .inform6
        case .inform7SourceFile, .inform7ExtensionFile:
            highlightType = .inform7
            intel = IFNaturalIntel()
        default:
            preconditionFailure("Found invalid file type \(IFProjectTypes.fileType(from: type).rawValue) from type '\(type)'")
        }

        // Create the file data
        var fileString = NSString(data: data, encoding: fileEncoding)
        if fileString == nil {
            // If opening with the suggested encoder doesn't work, fall back to using Latin1
            fileEncoding = String.Encoding.isoLatin1.rawValue
            fileString = NSString(data: data, encoding: fileEncoding)
        }

        guard let fileString else {
            let error = NSError(domain: NSCocoaErrorDomain,
                                code: NSFileReadUnknownStringEncodingError,
                                userInfo: [NSLocalizedDescriptionKey: "Error: failed to load file: could not find an acceptable character encoding",
                                           NSStringEncodingErrorKey: fileEncoding])
            NSLog("Error: failed to load file: could not find an acceptable character encoding")
            throw error
        }

        // Read again, as by Revert To Saved: the window shows this storage, so it's given the new text
        if IFSyntaxManager.isRegistered(fileStorage) {
            fileStorage.replaceCharacters(in: NSRange(location: 0, length: fileStorage.length),
                                          with: fileString as String)
            return
        }

        // Update fileStorage
        fileStorage = NSTextStorage(string: fileString as String)
        IFSyntaxManager.register(fileStorage,
                                 name: "single file",
                                 type: highlightType,
                                 intelligence: intel,
                                 undoManager: undoManager)
    }

    // MARK: - Retrieving document data

    var storage: NSTextStorage {
        return fileStorage
    }

    // MARK: - Whether or not this should be treated as read-only

    @objc(readOnly)
    var isReadOnly: Bool {
        @objc(isReadOnly) get {
            guard let fileURL else { return false }

            let filename = (fileURL.path as NSString).standardizingPath

            // Files in the extensions directory in the application should be treated as read-only
            let appDir = IFUtility.path(forInformInternalExtensions: "")

            if ((filename as NSString).lowercased as NSString).hasPrefix((appDir as NSString).lowercased) {
                return true
            }

            // Default is read-write
            return false
        }
    }

    public override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(NSDocument.save(_:)) {
            return !isReadOnly
        }

        return true
    }
}
