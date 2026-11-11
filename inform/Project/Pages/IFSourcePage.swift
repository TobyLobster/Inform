//
//  IFSourcePage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa

@objc @implementation extension IFSourcePage {
    /// The text storage object for this view
    private final var textStorage: NSTextStorage!
    private final var layoutManager: NSLayoutManager!
    private final var textContainer: NSTextContainer!
    private final var textView: IFSourceFileView!
    /// Just allows mouseDown to come through
    private final var scrollView: IFClickThroughScrollView!

    /// The name of the file that is open in this page
    private final var _openSourceFilepath: String?

    // The header page control
    private final var headerPageShown = false
    /// The 'source page' toggle
    private final var sourcePageControl: IFPageBarCell!
    /// The 'header page' toggle
    private final var headerPageControl: IFPageBarCell!
    /// The header page
    private final var headerPage: IFHeaderPage!

    // MARK: - Initialisation

    private final func setBackgroundColour() {
        let doc = parent?.document as? IFProject

        if doc?.projectFileType == .inform7ExtensionProject {
            textView.backgroundColor = IFPreferences.shared.extensionPaper.colour
        }
        else {
            textView.backgroundColor = IFPreferences.shared.sourcePaper.colour
        }

        // Set the cursor colour
        if textView.responds(to: #selector(setter: NSTextView.insertionPointColor)) {
            let theme = IFPreferences.shared.getCurrentTheme()
            let mainText = Int(IFSyntaxHighlightingOptionType.mainText.rawValue)
            if theme.options.count > mainText {
                textView.insertionPointColor = theme.options[mainText].colour
            }
        }
    }

    @objc(initWithProjectController:)
    init(projectController controller: IFProjectController) {
        super.init(nibName: "Source",
                   projectController: controller)

        // Notification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(preferencesChanged(_:)),
                                               name: .IFPreferencesEditingDidChange,
                                               object: IFPreferences.shared)

        //
        // Create textStorage and load the contents of our file into it.
        //
        let doc = parent?.document as? IFProject
        textStorage = doc?.storage(forFile: doc?.mainSourceFile)
        if textStorage == nil {
            textStorage = NSTextStorage()
        }

        //
        // Create a layoutManager, and connect it to our textStorage
        //
        layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        //
        // Create a text container, and add it to our layoutManager
        //
        textContainer = NSTextContainer(containerSize: view.frame.size)
        layoutManager.addTextContainer(textContainer)

        //
        // Create scroll view
        //
        scrollView = IFClickThroughScrollView(frame: view.frame)
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]
        let contentSize = scrollView.contentSize

        //
        // Set up the text view
        //
        textView = IFSourceFileView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height),
                                    textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat(Float.greatestFiniteMagnitude),
                                  height: CGFloat(Float.greatestFiniteMagnitude))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.delegate = self
        textView.allowsUndo = true
        textView.isRichText = false
        textView.enabledTextCheckingTypes = 0

        textView.textContainer?.containerSize = NSSize(width: contentSize.width,
                                                       height: CGFloat(Float.greatestFiniteMagnitude))
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 3, height: 6)

        //
        // Attach the views together
        //
        scrollView.documentView = textView
        view.addSubview(scrollView)

        //
        // Remember the filename
        //
        _openSourceFilepath = doc?.mainSourceFile

        //
        // Sanity check - make sure Undo is set up correctly
        //
        assert(textView.undoManager === doc?.undoManager, "Oops: undo manager broken")

        //
        // Create the header page
        //
        headerPage = IFHeaderPage()
        headerPage.delegate = self

        //
        // Create the header/source page controls
        //
        headerPageControl = IFPageBarCell(textCell: IFUtility.localizedString("HeaderPage",
                                                                              default: "Headings"))
        headerPageControl.target = self
        headerPageControl.action = #selector(showHeaderPage(_:))
        headerPageControl.radioGroup = 1

        sourcePageControl = IFPageBarCell(textCell: IFUtility.localizedString("SourcePage",
                                                                              default: "Source"))
        sourcePageControl.radioGroup = 1
        sourcePageControl.target = self
        sourcePageControl.action = #selector(showSourcePage(_:))
        sourcePageControl.state = .on

        textView.setSelectedRange(doc?.initialSelectionRange ?? NSRange(location: 0, length: 0))
        setBackgroundColour()
    }

    deinit {
        // The pane lets go of its pages on the main thread
        MainActor.assumeIsolated {
            // Main views and text classes
            scrollView?.removeFromSuperview()

            // Remove all notifications
            NotificationCenter.default.removeObserver(self)

            // Header page
            headerPage?.delegate = nil
        }
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Source Page Title",
                                         default: "Source")
    }

    public override var activeView: NSView {
        return textView
    }

    // MARK: - Misc

    func pasteSourceCode(_ sourceCode: String) {
        // Get the code that existed previously
        let currentRange = textView.selectedRange()
        let oldCode = textStorage.attributedSubstring(from: textView.selectedRange()).string
        let newRange = NSRange(location: currentRange.location, length: (sourceCode as NSString).length)

        // Describe how to undo this paste - select new range, paste in the old code, select current range
        let undo = textView.undoManager

        undo?.setActionName(IFUtility.localizedString("Paste Source Code"))
        undo?.beginUndoGrouping()

        undo?.registerUndo(withTarget: self) { page in
            page.select(currentRange)
        }
        undo?.registerUndo(withTarget: self) { page in
            page.pasteSourceCode(oldCode)
        }
        undo?.registerUndo(withTarget: self) { page in
            page.select(newRange)
        }

        undo?.endUndoGrouping()

        // Perform the action
        textView.replaceCharacters(in: currentRange,
                                   with: sourceCode)
        select(newRange)
    }

    // MARK: - Compiling

    func prepareToSave() {
        textView.breakUndoCoalescing()
    }

    // MARK: - Intelligence

    var currentIntelligence: IFIntelFile? {
        return IFSyntaxManager.intelligenceData(for: textStorage)
    }

    // MARK: - Indicating

    /// The range in the text view of a range of the file, first showing the section it's in if it's outside the
    /// section shown, or a location of NSNotFound if it still isn't shown
    private final func viewRange(for range: NSRange) -> NSRange {
        var range = range

        // Look at restricted range if necessary
        if IFSyntaxManager.isRestricted(textStorage,
                                        for: textView) {
            var restriction = IFSyntaxManager.restrictedRange(textStorage,
                                                              for: textView)
            if range.location >= restriction.location &&
                range.location < (restriction.location + restriction.length) {
                range.location -= restriction.location
            } else {
                // Try moving the restriction range to something nearer the indicated line
                let line = IFSourceLines.line(forCharacter: UInt(bitPattern: range.location),
                                              in: textStorage.string)

                let intel = currentIntelligence
                let symbol = intel?.nearestSymbol(toLine: line)

                if let symbol {
                    limitToSymbol(symbol,
                                  preserveScrollPos: false)
                }

                // If the line is now available, then we can highlight the appropriate character (all of them are if
                // the section was the whole story's, as there's no restriction now)
                if IFSyntaxManager.isRestricted(textStorage,
                                                for: textView) {
                    restriction = IFSyntaxManager.restrictedRange(textStorage,
                                                                  for: textView)
                    if range.location >= restriction.location &&
                        range.location < (restriction.location + restriction.length) {
                        range.location -= restriction.location
                    } else {
                        range.location = NSNotFound
                    }
                }
            }
        }

        return range
    }

    func indicateRange(_ range: NSRange) {
        let range = viewRange(for: range)
        if range.location == NSNotFound {
            return
        }

        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    }

    func indicateLine(_ line: Int32) {
        // Find out where the line is in the source view
        let lineRange = IFSourceLines.rangeOfText(onLine: line,
                                                  in: textStorage.string)

        if lineRange.location == NSNotFound {
            NSSound.beep() // DOH!
            return
        }

        // Show the find indicator
        indicateRange(lineRange)
    }

    func updateHighlightedLines() {
        let all = NSRange(location: 0, length: textView.textStorage?.length ?? 0)
        textView.layoutManager?.removeTemporaryAttribute(.backgroundColor,
                                                         forCharacterRange: all)

        // Highlight the lines as appropriate
        for highlight in parent?.highlights(forFile: openSourceFilepath) ?? [] {
            let line = highlight[0].int32Value
            let style = IFLineStyle(rawValue: UInt32(bitPattern: highlight[1].int32Value))!
            let background: NSColor

            switch style {
            case .neutral:
                background = NSColor(deviceRed: 0.3, green: 0.3, blue: 0.8, alpha: 1.0)

            case .highlight:
                background = NSColor(deviceRed: 0.3, green: 0.8, blue: 0.8, alpha: 1.0)

            case .error:
                background = NSColor(deviceRed: 0.7, green: 0.5, blue: 0.5, alpha: 1.0)

            default:
                background = NSColor(deviceRed: 0.8, green: 0.3, blue: 0.3, alpha: 1.0)
            }

            var lineRange = findLine(UInt(bitPattern: Int(line)))
            if IFSyntaxManager.isRestricted(textStorage,
                                            for: textView) {
                let restriction = IFSyntaxManager.restrictedRange(textStorage,
                                                                  for: textView)
                if lineRange.location >= restriction.location &&
                    lineRange.location < (restriction.location + restriction.length) {
                    lineRange.location -= restriction.location
                } else {
                    lineRange.location = NSNotFound
                }
            }

            if lineRange.location != NSNotFound {
                textView.layoutManager?.setTemporaryAttributes([.backgroundColor: background],
                                                               forCharacterRange: lineRange)
            }
        }
    }

    // MARK: - The selection

    var openSourceFilepath: String? {
        return _openSourceFilepath
    }

    var currentFile: String? {
        return (parent?.document as? IFProject)?.path(forSourceFile: openSourceFilepath)
    }

    private final func selectTextRange(_ range: NSRange) {
        // Restrict the range if needed, showing its section if it's outside the one shown
        let range = viewRange(for: range)
        if range.location == NSNotFound {
            return
        }

        // Display the range
        textView.scrollRangeToVisible(NSRange(location: range.location,
                                              length: range.length == 0 ? 1 : range.length))
        textView.setSelectedRange(range)
    }

    func move(toLine line: Int) {
        move(toLine: line,
             character: 0)
    }

    func move(toLine line: Int,
              character chrNo: Int32) {
        // Find out where the line is in the file (the text view has only the section shown)
        var linepos = IFSourceLines.start(ofLine: line,
                                          in: textStorage.string)

        if linepos == NSNotFound {
            NSSound.beep() // DOH!
            return
        }

        // Add the character position
        linepos &+= UInt(bitPattern: Int(chrNo))

        // Time to scroll
        selectTextRange(NSRange(location: Int(bitPattern: linepos), length: 0))
    }

    @objc(selectRange:)
    func select(_ range: NSRange) {
        textView.scrollRangeToVisible(range)
        textView.setSelectedRange(range)

        // NOTE: as this is used as part of the undo sequence for pasteSourceCode, this function must not contain an
        // undo action itself
    }

    func showSourceFile(_ file: String?) {
        guard let file else {
            return
        }

        let doc = parent?.document as? IFProject

        if let path = doc?.path(forSourceFile: file),
           let openPath = doc?.path(forSourceFile: openSourceFilepath),
           (path as NSString).isEqual(to: openPath) {
            // Nothing to do
            return
        }

        // Get text storage for file
        guard let fileStorage = doc?.storage(forFile: file) else {
            return
        }

        // Start editing text storage
        fileStorage.beginEditing()

        // Remove current selection.
        textView.setSelectedRange(NSRange(location: 0, length: 0))

        // Update current filepath
        _openSourceFilepath = doc?.path(forSourceFile: file)

        // Update current storage, leaving the last file whole in this view, but still highlighted, with its headings,
        // for any other view of it
        IFSyntaxManager.removeRestriction(textStorage,
                                          for: textView)

        textStorage = fileStorage
        textView.layoutManager?.replaceTextStorage(textStorage)

        // All of the file is shown, without the tears of a section of the last one
        textView.setTornAtTop(false)
        textView.setTornAtBottom(false)

        // (The project registers the storage of each file as it reads it)
        if !IFSyntaxManager.isRegistered(textStorage) {
            IFSyntaxManager.register(textStorage,
                                     filename: (file as NSString).lastPathComponent,
                                     intelligence: IFProjectTypes.intelligence(forFilename: file),
                                     undoManager: doc?.undoManager)
        }

        // Show its headings
        parent?.headerController.update(fromIntelligence: currentIntelligence)

        // Stop editing text storage
        fileStorage.endEditing()

        // Is the file editable?
        textView.isEditable = true
    }

    func findLine(_ line: UInt) -> NSRange {
        return IFSourceLines.range(ofLine: line,
                                   in: textStorage.string)
    }

    // MARK: - Breakpoints

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        return true
    }

    // MARK: - Spell checking

    func setSpellChecking(_ checkSpelling: Bool) {
        textView.isContinuousSpellCheckingEnabled = checkSpelling
    }

    // MARK: - The headings browser

    public override var toolbarCells: [IFPageBarCell] {
        return [sourcePageControl, headerPageControl]
    }

    // MARK: - Managing the source text view

    private final func hasFirstResponder() -> Bool {
        // Returns true if this page has the first responder

        // Find the first responder that is a view
        var firstResponder = textView.window?.firstResponder
        while let responder = firstResponder, !(responder is NSView) {
            firstResponder = responder.nextResponder
        }

        // See if the source text view is in the first responder hierarchy
        var respondingView = firstResponder as? NSView
        while let responding = respondingView {
            if responding === textView {
                return true
            }
            if responding === view {
                return true
            }
            respondingView = responding.superview
        }

        return false
    }

    // MARK: - The header page

    private final func highlightHeaderSection() {
        // Get the text storage
        if IFSyntaxManager.isRestricted(textStorage,
                                        for: textView) {
            // Work out the line numbers the restriction applies to
            let restriction = IFSyntaxManager.restrictedRange(textStorage,
                                                              for: textView)

            // Highlight the appropriate node
            headerPage.highlightNode(withLines: IFSourceSections.lines(of: restriction,
                                                                       in: textStorage.string))
        } else {
            // Highlight nothing
            headerPage.select(nil)
        }
    }

    @objc private final func animationFinished(_ viewAnimator: IFViewAnimator) {
        let hasFirstResponder = self.hasFirstResponder()
        if hasFirstResponder {
            setFirstResponder()
        }
    }

    @IBAction func toggleHeaderPage(_ sender: Any?) {
        if headerPageShown {
            // Hide the header page and show the source page
            headerPage.controller = nil
            scrollView.frame = view.subviews[0].frame

            // Animate to the new view
            let animator = IFViewAnimator()

            animator.setTime(0.3)
            animator.prepare(toAnimate: view.subviews[0],
                             focus: nil)
            animator.animate(to: scrollView,
                             focus: textView,
                             style: .animateLeft,
                             sendMessage: #selector(animationFinished(_:)),
                             to: self)

            sourcePageControl.state = .on
            headerPageControl.state = .off
            headerPageShown = false
        } else {
            // Show the header page
            headerPage.controller = parent?.headerController
            headerPage.pageView.frame = view.subviews[0].frame
            highlightHeaderSection()

            // Animate to the new view
            let animator = IFViewAnimator()

            animator.setTime(0.3)
            animator.prepare(toAnimate: view.subviews[0],
                             focus: headerPage.headerView)
            animator.animate(to: headerPage.pageView,
                             focus: headerPage.headerView,
                             style: .animateRight,
                             sendMessage: #selector(animationFinished(_:)),
                             to: self)

            sourcePageControl.state = .off
            headerPageControl.state = .on
            headerPageShown = true
        }
    }

    @IBAction func showHeaderPage(_ sender: Any?) {
        if !headerPageShown {
            toggleHeaderPage(self)
        }
    }

    @IBAction private final func showSourcePage(_ sender: Any?) {
        if headerPageShown {
            toggleHeaderPage(self)
        }
    }

    // MARK: - Helping out with the cursor

    private final func cursorOffset() -> CGFloat {
        // Returns the offset of the cursor (beginning of the current selection) relative to the top
        // of the view

        // Retrieve the currently selected range
        let selection = textView.selectedRange()

        // Get the offset of this location in the text view
        guard let layout = textView.layoutManager,
              let container = textView.textContainer else {
            return 0
        }
        let glyphRange = layout.glyphRange(forCharacterRange: selection,
                                           actualCharacterRange: nil)

        var boundingRect = layout.boundingRect(forGlyphRange: glyphRange,
                                               in: container)
        boundingRect.origin.y += textView.textContainerOrigin.y

        // Convert to coordinates relative to the containing view
        boundingRect = textView.convert(boundingRect,
                                        to: scrollView)

        // Offset is the minimum position of the bounding rectangle
        return boundingRect.minY
    }

    // MARK: - Header page delegate methods

    private final func removeLimits() {
        if IFSyntaxManager.isRestricted(textStorage,
                                        for: textView) {
            let undo = textView.undoManager
            let restriction = IFSyntaxManager.restrictedRange(textStorage,
                                                              for: textView)
            undo?.registerUndo(withTarget: self) { page in
                page.limitToRange(restriction,
                                  preserveScrollPos: false)
            }

            // Switch text storage
            textView.layoutManager?.replaceTextStorage(textStorage)

            IFSyntaxManager.removeRestriction(textStorage,
                                              for: textView)
            highlightHeaderSection()

            textView.setTornAtTop(false)
            textView.setTornAtBottom(false)
        }
    }

    private final func limitToRange(_ range: NSRange,
                                    preserveScrollPos: Bool) {
        // Record the current cursor offset and selection if preservation is turned on
        var originalCursorOffset: CGFloat = 0
        var selectionRange = NSRange(location: 0, length: 0)

        if preserveScrollPos {
            originalCursorOffset = cursorOffset()
            selectionRange = textView.selectedRange()
            textView.layoutManager?.backgroundLayoutEnabled = false
        }

        // Get the text storage object
        let undo = textView.undoManager

        if !IFSyntaxManager.isRestricted(textStorage,
                                         for: textView) {
            // Set up the restriction
            IFSyntaxManager.restrictStorage(textStorage,
                                            range: range,
                                            for: textView)
            if let restrictedStorage = IFSyntaxManager.restrictedTextStorage(textStorage,
                                                                             for: textView) {
                textView.layoutManager?.replaceTextStorage(restrictedStorage)
            }

            undo?.registerUndo(withTarget: self) { page in
                page.removeLimits()
            }
        } else {
            let restrictedRange = IFSyntaxManager.restrictedRange(textStorage,
                                                                  for: textView)
            if preserveScrollPos {
                selectionRange.location += restrictedRange.location
            }

            undo?.registerUndo(withTarget: self) { page in
                page.limitToRange(restrictedRange,
                                  preserveScrollPos: false)
            }
            // Set the restriction range
            IFSyntaxManager.restrictStorage(textStorage,
                                            range: range,
                                            for: textView)
        }

        highlightHeaderSection()

        // Display or hide the tears at the top and bottom
        textView.setTornAtTop(range.location != 0)
        textView.setTornAtBottom((range.location + range.length) < textStorage.length)

        // Refresh any highlighting
        updateHighlightedLines()

        // Reset the selection and try to scroll back to the original position if we can
        if preserveScrollPos {
            // Update the selection
            if range.location <= selectionRange.location {
                // Selection is at or after the beginning of the range
                selectionRange.location -= range.location

                if selectionRange.location > range.length {
                    // Selection is after the end of the range; just use the start of the region
                    selectionRange.location = 0
                    selectionRange.length = 0
                } else if selectionRange.location + selectionRange.length > range.length {
                    // Selection extends beyond the end of the region
                    selectionRange.length = range.length - selectionRange.location
                }
            } else {
                // Just go to the start of the region if the selection is out of bounds
                selectionRange.location = 0
                selectionRange.length = 0

                // TODO: selection could start before the range and extend into it; this will work
                // differently from the selection extending over the end of the range
            }

            // Set the selection
            textView.setSelectedRange(selectionRange)

            // Scroll to the top to avoid some glitching
            textView.scroll(NSPoint(x: 0, y: 0))

            // Get the cursor scroll offset
            let newCursorOffset = cursorOffset()
            let scrollOffset = floor(newCursorOffset - originalCursorOffset)

            // Scroll the view
            var scrollPos = scrollView.contentView.documentVisibleRect.origin
            scrollPos.y += scrollOffset
            if range.location > 0 {
                scrollPos.y += 18 // HACK
            }
            if scrollPos.y < 0 {
                scrollPos.y = 0
            }
            scrollView.contentView.scroll(to: scrollPos)

            textView.layoutManager?.backgroundLayoutEnabled = true
        }
    }

    private final func limitToSymbol(_ symbol: IFIntelSymbol?,
                                     preserveScrollPos: Bool) {
        let intelFile = parent?.headerController.intelFile

        guard let symbol, symbol !== intelFile?.firstSymbol else {
            // Remove the source text limitations
            removeLimits()

            // Scroll to the top
            textView.scroll(NSPoint(x: 0, y: 0))

            // Redisplay the source code
            if headerPageShown {
                toggleHeaderPage(self)
            }

            return
        }

        // Get the range we need to limit to
        let limitRange = IFSourceSections.range(ofSection: symbol,
                                                inFile: intelFile,
                                                in: textStorage.string)
        if limitRange.location == NSNotFound {
            return
        }

        // Perform the limitation
        limitToRange(limitRange,
                     preserveScrollPos: preserveScrollPos)

        // Redisplay the source code
        if headerPageShown {
            toggleHeaderPage(self)
        }

        // Scroll to the top
        if !preserveScrollPos {
            textView.scroll(NSPoint(x: 0, y: 0))
        }
    }

    private final func undoReplaceCharacters(in range: NSRange,
                                             with string: String) {
        // Create an undo action
        let undo = undoManager(for: textView)
        let newRange = NSRange(location: range.location, length: (string as NSString).length)
        let oldString = (textStorage.string as NSString).substring(with: range)

        undo?.registerUndo(withTarget: self) { page in
            page.undoReplaceCharacters(in: newRange,
                                       with: oldString)
        }
        undo?.setActionName(IFUtility.localizedString("Edit Header"))

        // Replace the text for this range
        textStorage.mutableString.replaceCharacters(in: range,
                                                    with: string)
    }

    private final func currentSection() -> IFIntelSymbol? {
        // Get the text storage
        if IFSyntaxManager.isRestricted(textStorage,
                                        for: textView) {
            let intelFile = currentIntelligence

            // Work out the line numbers the restriction applies to
            let restriction = IFSyntaxManager.restrictedRange(textStorage,
                                                              for: textView)

            // Return the nearest section
            return IFSourceSections.section(atCharacter: UInt(bitPattern: restriction.location),
                                            inFile: intelFile,
                                            in: textStorage.string)
        }

        return nil
    }

    func sourceFileShowPreviousSection(_ sender: Any?) {
        let section = currentSection()
        let previousSection = IFSourceSections.section(before: section,
                                                       inFile: currentIntelligence)

        if let previousSection {
            let animator = IFViewAnimator()

            animator.setTime(0.1)
            animator.prepare(toAnimate: view,
                             focus: nil)

            limitToSymbol(previousSection,
                          preserveScrollPos: false)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            animator.animate(to: view,
                             focus: textView,
                             style: .animateDown,
                             sendMessage: #selector(animationFinished(_:)),
                             to: self)
        } else {
            let animator = IFViewAnimator()

            animator.setTime(0.1)
            animator.prepare(toAnimate: view,
                             focus: nil)

            removeLimits()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            animator.animate(to: view,
                             focus: textView,
                             style: .animateDown,
                             sendMessage: #selector(animationFinished(_:)),
                             to: self)
        }
    }

    func sourceFileShowNextSection(_ sender: Any?) {
        let section = currentSection()
        let nextSection = IFSourceSections.section(after: section)

        if let nextSection {
            let animator = IFViewAnimator()

            animator.setTime(0.3)
            animator.prepare(toAnimate: view,
                             focus: nil)

            limitToSymbol(nextSection,
                          preserveScrollPos: false)
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            animator.animate(to: view,
                             focus: textView,
                             style: .animateUp,
                             sendMessage: #selector(animationFinished(_:)),
                             to: self)
        }
    }

    private final func setFirstResponder() {
        // View animation has finished and we want to reset the source text view as the first responder
        textView.window?.makeFirstResponder(textView)
    }

    private final func symbolNearestSelection() -> IFIntelSymbol? {
        // Work out the absolute selection
        var selection = textView.selectedRange()
        if IFSyntaxManager.isRestricted(textStorage,
                                        for: textView) {
            selection.location += IFSyntaxManager.restrictedRange(textStorage,
                                                                  for: textView).location
        }

        // Retrieve the symbol nearest to the line the selection is on
        let intelFile = currentIntelligence
        let nearestSymbol = IFSourceSections.section(atCharacter: UInt(bitPattern: selection.location),
                                                     inFile: intelFile,
                                                     in: textStorage.string)

        return nearestSymbol
    }

    @IBAction func showEntireSource(_ sender: Any?) {
        // Display everything
        limitToRange(NSRange(location: 0, length: textStorage.length),
                     preserveScrollPos: true)
    }

    @IBAction func showCurrentSectionOnly(_ sender: Any?) {
        // Get the symbol nearest to the current selection
        let cursorSection = symbolNearestSelection()

        // Limit the displayed range to it
        if let cursorSection {
            limitToSymbol(cursorSection,
                          preserveScrollPos: true)
        }
    }

    @IBAction func showFewerHeadings(_ sender: Any?) {
        // Get the currently displayed section
        var currentSection = currentSection()
        if currentSection == nil {
            // Ensures we don't end up picking the 'title' section which includes the whole file anyway
            currentSection = currentIntelligence?.firstSymbol
        }

        // Also get the section that the cursor is in
        let cursorSection = symbolNearestSelection()

        // Find the section under the current one that the cursor is in
        let lowerSection = IFSourceSections.section(below: currentSection,
                                                    towards: cursorSection)
        if let lowerSection {
            // Restrict to this section
            limitToSymbol(lowerSection,
                          preserveScrollPos: true)
        }
    }

    @IBAction func showMoreHeadings(_ sender: Any?) {
        // Limit to one section above the current section
        guard let currentSection = currentSection() else {
            return
        }

        let parentSection = IFSourceSections.section(above: currentSection,
                                                     inFile: currentIntelligence)
        if let parentSection {
            limitToSymbol(parentSection,
                          preserveScrollPos: true)
        } else {
            showEntireSource(self)
        }
    }

    @objc private final func preferencesChanged(_ not: Notification) {
        setBackgroundColour()
        textView.needsDisplay = true
    }
}

// The page's header conforms to these protocols, whose optional methods an @implementation doesn't take
extension IFSourcePage {
    // MARK: - Text view delegate methods

    @objc(undoManagerForTextView:)
    public func undoManager(for aTextView: NSTextView) -> UndoManager? {
        // Always use the document undo manager
        return (parent?.document as? IFProject)?.undoManager
    }

    // MARK: - Header page delegate methods

    @objc(refreshHeaders:)
    public func refreshHeaders(_ controller: IFHeaderController) {
        // Relayed via the IFHeaderPage (where it's relayed via the view)
        highlightHeaderSection()
    }

    @objc(headerPage:limitToHeader:)
    public func headerPage(_ page: IFHeaderPage?,
                           limitTo header: IFHeader) {
        // Work out the following symbol
        let symbol = header.symbol

        limitToSymbol(symbol,
                      preserveScrollPos: false)
    }

    @objc(headerView:updateNode:withNewTitle:)
    public func headerView(_ view: IFHeaderView,
                           update node: IFHeaderNode,
                           withNewTitle newTitle: String) {
        let header = node.header
        let symbol = header.symbol
        let intel = currentIntelligence

        let lastValue = header.headingName

        // Work out which line needs to be edited
        let line = (intel?.line(for: symbol) ?? 0) + 1

        // Get the range of the line
        let lineRange = findLine(line)
        if lineRange.location == NSNotFound {
            return
        }

        let currentValue = (textStorage.string as NSString).substring(with: lineRange)

        // If the line currently contains the previous value, then replace it with the new value
        if (currentValue as NSString).isEqual(to: lastValue) && !(currentValue as NSString).isEqual(to: newTitle) {
            // Restrict to the selected node
            headerPage(nil,
                       limitTo: header)

            // Create an undo action
            let undo = undoManager(for: textView)
            let newRange = NSRange(location: lineRange.location, length: (newTitle as NSString).length)
            let oldString = (textStorage.string as NSString).substring(with: lineRange)
            undo?.registerUndo(withTarget: self) { page in
                page.undoReplaceCharacters(in: newRange,
                                           with: oldString)
            }
            undo?.setActionName(IFUtility.localizedString("Edit Header"))

            // Replace the text for this node
            textStorage.mutableString.replaceCharacters(in: lineRange,
                                                        with: newTitle)
        }

        parent?.headerController.update(fromIntelligence: currentIntelligence)
    }
}
