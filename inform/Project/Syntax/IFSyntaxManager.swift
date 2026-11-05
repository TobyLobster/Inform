//
//  IFSyntaxManager.swift
//  Inform
//
//  Created by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFSyntaxManager.h.
//

import Cocoa

/// The syntax data of each registered text storage, found by the storage's identity (the storage isn't retained)
private var storages: [ObjectIdentifier: IFSyntaxData] = [:]

@objc @implementation extension IFSyntaxManager {

    ///
    /// Internal
    ///
    @objc(dataForStorage:)
    class func data(for storage: NSTextStorage) -> IFSyntaxData? {
        return storages[ObjectIdentifier(storage)]
    }

    //
    // Registration
    //
    @objc(registerTextStorage:name:type:intelligence:undoManager:)
    class func register(_ storage: NSTextStorage,
                        name: String,
                        type: IFHighlightType,
                        intelligence: IFSyntaxIntelligence?,
                        undoManager: UndoManager?) {
        let data = IFSyntaxData(storage: storage,
                                name: name,
                                type: type,
                                intelligence: intelligence,
                                undoManager: undoManager)
        //NSLog(@"*** Register %@ with storage %d", name, (int) storage);
        storages[ObjectIdentifier(storage)] = data
    }

    @objc(registerTextStorage:filename:intelligence:undoManager:)
    class func register(_ storage: NSTextStorage,
                        filename: String,
                        intelligence: IFSyntaxIntelligence?,
                        undoManager: UndoManager?) {
        IFSyntaxManager.register(storage,
                                 name: filename,
                                 type: IFProjectTypes.highlighterType(forFilename: filename),
                                 intelligence: intelligence,
                                 undoManager: undoManager)
    }

    class func unregisterTextStorage(_ storage: NSTextStorage) {
        if IFSyntaxManager.data(for: storage) != nil {
            // NSLog(@"*** Unregister %@ with storage %d", [data name], (int) storage);
            storages.removeValue(forKey: ObjectIdentifier(storage))
        } else {
            // NSLog(false, @"removing storage %@ that's not registered", storage);
        }
    }

    class func isRegistered(_ storage: NSTextStorage) -> Bool {
        let data = IFSyntaxManager.data(for: storage)
        return data != nil
    }

    //
    // Syntax highlighting
    //
    class func highlightAll(_ storage: NSTextStorage,
                            forceUpdateTabs: Bool) {
        let data = IFSyntaxManager.data(for: storage)
        data?.highlightAllForceUpdateTabs(forceUpdateTabs)
    }

    class func preferencesChanged(_ storage: NSTextStorage) {
        let data = IFSyntaxManager.data(for: storage)
        data?.preferencesChanged(nil)
    }

    //
    // Restricted Storage
    //
    @objc(restrictStorage:range:forTextView:)
    class func restrictStorage(_ storage: NSTextStorage,
                               range: NSRange,
                               for view: NSTextView) {
        let data = IFSyntaxManager.data(for: storage)
        data?.restrict(to: range,
                       for: view)
    }

    @objc(removeRestriction:forTextView:)
    class func removeRestriction(_ storage: NSTextStorage,
                                 for view: NSTextView) {
        let data = IFSyntaxManager.data(for: storage)
        data?.removeRestriction(for: view)
    }

    @objc(isRestricted:forTextView:)
    class func isRestricted(_ storage: NSTextStorage,
                            for view: NSTextView) -> Bool {
        let data = IFSyntaxManager.data(for: storage)
        return data?.isRestricted(for: view) ?? false
    }

    @objc(restrictedRange:forTextView:)
    class func restrictedRange(_ storage: NSTextStorage,
                               for view: NSTextView) -> NSRange {
        let data = IFSyntaxManager.data(for: storage)
        // With no data, the range is empty at the start (as Objective-C's message to nil gave)
        return data?.restrictedRange(for: view) ?? NSRange(location: 0, length: 0)
    }

    @objc(restrictedTextStorage:forTextView:)
    class func restrictedTextStorage(_ storage: NSTextStorage,
                                     for view: NSTextView) -> NSTextStorage? {
        let data = IFSyntaxManager.data(for: storage)
        return data?.restrictedTextStorage(for: view)
    }

    @objc(registeredStorageForTextView:)
    class func registeredStorage(for view: NSTextView) -> NSTextStorage? {
        guard let storage = view.textStorage else {
            return nil
        }
        if IFSyntaxManager.isRegistered(storage) {
            return storage
        }

        // A view restricted to part of the text shows a copy of that part
        for data in storages.values {
            if data.restrictedTextStorage(for: view) === storage {
                return data.textStorage
            }
        }
        return nil
    }

    //
    // Renumbering sections
    //
    @objc(textForLineWithStorage:lineNumber:)
    class func textForLine(with storage: NSTextStorage,
                           lineNumber line: Int32) -> String? {
        let data = IFSyntaxManager.data(for: storage)
        return data?.text(forLine: line)
    }

    @objc(replaceLineWithStorage:lineNumber:withLine:)
    class func replaceLine(with storage: NSTextStorage,
                           lineNumber: Int32,
                           withLine line: String) {
        let data = IFSyntaxManager.data(for: storage)
        data?.replaceLine(lineNumber,
                          withLine: line)
    }

    //
    // Intelligence
    //
    @objc(intelligenceDataForStorage:)
    class func intelligenceData(for storage: NSTextStorage) -> IFIntelFile? {
        let data = IFSyntaxManager.data(for: storage)
        return data?.intelligenceData
    }
}
