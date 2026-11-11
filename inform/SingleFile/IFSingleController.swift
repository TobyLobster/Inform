//
//  IFSingleController.swift
//  Inform
//
//  Created by Andrew Hunter on 25/06/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFSingleController.h.
//

import Cocoa

/// The code of an ASCII character, to compare with a `unichar` as a C character constant would be
private func ascii(_ scalar: Unicode.Scalar) -> unichar {
    return unichar(scalar.value)
}

@objc @implementation extension IFSingleController {
    /// The textview used to display the document itself
    @IBOutlet private final var fileView: IFSourceFileView?
    private final var isExtension: Bool
    private final var isInform7: Bool
    private final var initialSelectionRange: NSRange

    private final var sharedActions: IFSourceSharedActions

    init(initialSelectionRange anInitialSelectionRange: NSRange) {
        sharedActions = IFSourceSharedActions()

        initialSelectionRange = anInitialSelectionRange
        isExtension = false
        isInform7 = false

        // The nib is named by windowNibName, as a Swift initialiser can't call initWithWindowNibName:
        super.init(window: nil)

        // Notification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferencesChanged(_:)),
                                               name: .IFPreferencesEditingDidChange,
                                               object: IFPreferences.shared)
    }

    // Swift needs this, as NSWindowController's is required. The Objective-C inherited it, starting with nothing set.
    public required init?(coder: NSCoder) {
        sharedActions = IFSourceSharedActions()

        initialSelectionRange = NSRange(location: 0, length: 0)
        isExtension = false
        isInform7 = false

        super.init(coder: coder)
    }

    public override var windowNibName: NSNib.Name? {
        return "SingleFile"
    }

    deinit {
        // Notification
        NotificationCenter.default.removeObserver(self)
    }

    public override func windowDidLoad() {
        IFWelcomeWindow.hide()
    }

    nonisolated public override func awakeFromNib() {
        // Nibs are loaded on the main thread
        MainActor.assumeIsolated {
            let document = self.document as? IFSingleFile

            // Set the window frame save name
            windowFrameAutosaveName = "SingleFile"

            // Set the view's text appropriately
            if let storage = document?.storage {
                fileView?.layoutManager?.replaceTextStorage(storage)
            }

            fileView?.isEditable = !(document?.isReadOnly ?? false)
            fileView?.isRichText = false
            fileView?.enabledTextCheckingTypes = 0
            fileView?.setSelectedRange(initialSelectionRange)

            let filename = (document?.fileURL?.path as NSString?)?.standardizingPath
            let dotExtension = (filename as NSString?)?.pathExtension.lowercased()

            isExtension = dotExtension == "i7x" ||
                          dotExtension == "h" ||
                          dotExtension == ""
            isInform7 = dotExtension == "i7x" ||
                        dotExtension == "ni" ||
                        dotExtension == "i7" ||
                        dotExtension == ""

            // Spell checking
            setSourceSpellChecking((NSApp.delegate as? IFAppDelegate)?.sourceSpellChecking ?? false)

            setBackgroundColour()
        }
    }

    // MARK: - Menu items

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let itemSelector = menuItem.action

        if itemSelector == #selector(NSDocument.save(_:)) {
            return !((document as? IFSingleFile)?.isReadOnly ?? false)
        }
        // Format options
        if itemSelector == #selector(shiftLeft(_:)) ||
           itemSelector == #selector(shiftRight(_:)) ||
           itemSelector == #selector(renumberSections(_:)) {
            // First responder must be an NSTextView object
            if !(window?.firstResponder is NSTextView) {
                return false
            }
        }

        if itemSelector == #selector(commentOutSelection(_:)) ||
           itemSelector == #selector(uncommentSelection(_:)) {
            // Must be an Inform 7 file
            if !isInform7 {
                return false
            }

            // First responder must be a NSTextView object
            guard let textView = window?.firstResponder as? NSTextView else {
                return false
            }

            // There must be a non-zero length selection
            if textView.selectedRange().length == 0 {
                return false
            }
        }

        if itemSelector == #selector(renumberSections(_:)) {
            let responder = window?.firstResponder

            // First responder must be an NSTextView object containing a NSTextStorage with some intel data
            guard let textView = responder as? NSTextView else {
                return false
            }

            // Text with no intelligence, such as Inform 6, still has intelligence data, with no headings in it
            guard let storage = IFSyntaxManager.registeredStorage(for: textView),
                  IFSyntaxManager.data(for: storage)?.intelligence != nil else {
                return false
            }
        }

        return true
    }

    func setSourceSpellChecking(_ spellChecking: Bool) {
        fileView?.isContinuousSpellCheckingEnabled = spellChecking
    }

    @IBAction private func commentOutSelection(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.commentOutSelection(in: document, textView: textView)
        }
    }

    @IBAction private func uncommentSelection(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.uncommentSelection(in: document, textView: textView)
        }
    }

    @IBAction private func shiftLeft(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.shiftLeftTextView(in: document, textView: textView)
        }
    }

    @IBAction private func shiftRight(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.shiftRightTextView(in: document, textView: textView)
        }
    }

    @IBAction private func renumberSections(_ sender: Any?) {
        let responder = window?.firstResponder

        if let textView = responder as? NSTextView, let document = document as? NSDocument {
            sharedActions.renumberSections(in: document, textView: textView)
        }
    }

    // MARK: - Highlighting lines

    func highlightSourceFileLine(_ line: Int, inFile file: String, style: IFLineStyle) {
        // Find out where the line is in the source view
        let store: NSString = (document as? IFSingleFile)?.storage.mutableString ?? ""
        let length = store.length

        var lineno = 1
        var linepos = 0
        if line > lineno {
            var x = 0
            while x < length {
                let chr = store.character(at: x)

                if chr == ascii("\n") || chr == ascii("\r") {
                    let otherchar = chr == ascii("\n") ? ascii("\r") : ascii("\n")

                    lineno += 1
                    linepos = x + 1

                    // Deal with DOS line endings
                    if linepos < length && store.character(at: linepos) == otherchar {
                        x += 1; linepos += 1
                    }

                    if lineno == line {
                        break
                    }
                }
                x += 1
            }
        }

        if lineno != line {
            NSSound.beep() // DOH!
            return
        }

        var lineLength = 0
        var x = 0
        while x < length - linepos {
            if store.character(at: x + linepos) == ascii("\n")
                || store.character(at: x + linepos) == ascii("\r") {
                break
            }
            lineLength += 1
            x += 1
        }

        // Show the find indicator
        let range = NSRange(location: linepos, length: lineLength)
        fileView?.setSelectedRange(range)
        fileView?.scrollRangeToVisible(range)
        fileView?.showFindIndicator(for: range)
    }

    func indicateRange(_ rangeToIndicate: NSRange) {
        //
        // Indicates a range of text (scrolling to show the match if necessary).
        // Used when user clicks on a search result for 'Find In Files'
        //
        fileView?.setSelectedRange(NSRange(location: rangeToIndicate.location, length: 0))
        fileView?.scrollRangeToVisible(rangeToIndicate)
        fileView?.setSelectedRange(rangeToIndicate)
        fileView?.showFindIndicator(for: rangeToIndicate)
    }

    private final func setBackgroundColour() {
        if isExtension {
            fileView?.backgroundColor = IFPreferences.shared.extensionPaper.colour
        } else {
            fileView?.backgroundColor = IFPreferences.shared.sourcePaper.colour
        }
    }

    @objc private func preferencesChanged(_ not: Notification) {
        setBackgroundColour()
        fileView?.needsDisplay = true
    }
}
