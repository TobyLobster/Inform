//
//  IFEditingPreferences.swift
//  Inform
//
//  Created by Toby Nelson in 2014
//  Translated from Objective-C in November 2026. The interface is still IFEditingPreferences.h.
//

import Cocoa

@objc @implementation extension IFEditingPreferences {
    /// The preferences the pane shows and sets
    private final var preferences: IFPreferences

    // Text section
    @IBOutlet private final var fontFamily: NSTextField?
    @IBOutlet private final var appTextSize: NSSlider?

    // Syntax highlighting section
    @IBOutlet private final var enableSyntaxHighlighting: NSButton?
    @IBOutlet private final var restoreSettingsButton: NSButton?
    @IBOutlet private final var rowHeadings: NSTextField?
    @IBOutlet private final var rowMainText: NSTextField?
    @IBOutlet private final var rowComments: NSTextField?
    @IBOutlet private final var rowQuotedText: NSTextField?
    @IBOutlet private final var rowTextSubstitutions: NSTextField?

    @IBOutlet private final var headingsBold: NSButton?
    @IBOutlet private final var mainTextBold: NSButton?
    @IBOutlet private final var commentsBold: NSButton?
    @IBOutlet private final var quotedTextBold: NSButton?
    @IBOutlet private final var textSubstitutionsBold: NSButton?

    @IBOutlet private final var headingsItalic: NSButton?
    @IBOutlet private final var mainTextItalic: NSButton?
    @IBOutlet private final var commentsItalic: NSButton?
    @IBOutlet private final var quotedTextItalic: NSButton?
    @IBOutlet private final var textSubstitutionsItalic: NSButton?

    @IBOutlet private final var headingsUnderline: NSButton?
    @IBOutlet private final var mainTextUnderline: NSButton?
    @IBOutlet private final var commentsUnderline: NSButton?
    @IBOutlet private final var quotedTextUnderline: NSButton?
    @IBOutlet private final var textSubstitutionsUnderline: NSButton?

    @IBOutlet private final var headingsFontSize: NSSlider?
    @IBOutlet private final var mainTextFontSize: NSSlider?
    @IBOutlet private final var commentsFontSize: NSSlider?
    @IBOutlet private final var quotedTextFontSize: NSSlider?
    @IBOutlet private final var textSubstitutionsFontSize: NSSlider?

    // Tab width section
    @IBOutlet private final var tabStopSlider: NSSlider?
    @IBOutlet private final var previewView: NSTextView?
    @IBOutlet private final var tabStopView: NSTextView?

    // Indenting section
    @IBOutlet private final var autoIndentAfterNewline: NSButton?
    @IBOutlet private final var autoSpaceTableColumns: NSButton?

    // Numbering section
    @IBOutlet private final var autoNumberSections: NSButton?

    // Text storage for previews
    private final var previewStorage: NSTextStorage?
    private final var tabStopStorage: NSTextStorage?

    private final var defaultSet: IFEditingPreferencesSet
    private final var currentSet: IFEditingPreferencesSet

    override convenience init() {
        self.init(preferences: IFPreferences.shared)
    }

    init(preferences thePreferences: IFPreferences) {
        preferences = thePreferences
        defaultSet = IFEditingPreferencesSet()
        currentSet = IFEditingPreferencesSet()
        super.init(nibName: "EditingPreferences")

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reflectCurrentPreferences),
                                               name: .IFPreferencesEditingDidChange,
                                               object: preferences)

        // Create the preview
        var oldStorage = previewView?.textStorage
        let previewStorage = NSTextStorage(string: oldStorage?.string ?? "")
        self.previewStorage = previewStorage
        IFSyntaxManager.register(previewStorage,
                                 name: "Editing Preferences (preview)",
                                 type: .inform7,
                                 intelligence: nil,
                                 undoManager: nil)

        previewView?.layoutManager?.replaceTextStorage(previewStorage)

        // ... and the tab preview
        oldStorage = tabStopView?.textStorage
        let tabStopStorage = NSTextStorage(string: oldStorage?.string ?? "")
        self.tabStopStorage = tabStopStorage

        IFSyntaxManager.register(tabStopStorage,
                                 name: "Editing Preferences (tab stops)",
                                 type: .inform7,
                                 intelligence: nil,
                                 undoManager: nil)

        tabStopView?.layoutManager?.replaceTextStorage(tabStopStorage)
        tabStopView?.textContainerInset = NSSize(width: 0, height: 2)

        // Register for notifications about view size changes
        preferenceView?.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(viewWidthChanged(_:)),
                                               name: NSView.frameDidChangeNotification,
                                               object: preferenceView)

        reflectCurrentPreferences()
    }

    deinit {
        // The preferences window lets go of its panes on the main thread
        MainActor.assumeIsolated {
            if let previewStorage {
                IFSyntaxManager.unregisterTextStorage(previewStorage)
            }
            if let tabStopStorage {
                IFSyntaxManager.unregisterTextStorage(tabStopStorage)
            }
        }
    }

    // MARK: - PreferencePane overrides

    public override var preferenceName: String {
        return "Editing"
    }

    public override var toolbarImage: NSImage? {
        return Bundle(for: type(of: self)).image(forResource: "App/highlighter")
    }

    public override var tooltip: String? {
        return IFUtility.localizedString("Editing preferences tooltip")
    }

    public override var maxHeight: CGFloat {
        return .greatestFiniteMagnitude
    }

    public override var minHeight: CGFloat {
        return 574.0
    }

    // MARK: - Receiving data from/updating the interface

    private final func updateDependentUIElements() {
        let enabled = (enableSyntaxHighlighting?.state == .on)

        rowHeadings?.isEnabled = enabled
        rowMainText?.isEnabled = enabled
        rowComments?.isEnabled = enabled
        rowQuotedText?.isEnabled = enabled
        rowTextSubstitutions?.isEnabled = enabled

        headingsBold?.isEnabled = enabled
        mainTextBold?.isEnabled = enabled
        commentsBold?.isEnabled = enabled
        quotedTextBold?.isEnabled = enabled
        textSubstitutionsBold?.isEnabled = enabled

        headingsItalic?.isEnabled = enabled
        mainTextItalic?.isEnabled = enabled
        commentsItalic?.isEnabled = enabled
        quotedTextItalic?.isEnabled = enabled
        textSubstitutionsItalic?.isEnabled = enabled

        headingsUnderline?.isEnabled = enabled
        mainTextUnderline?.isEnabled = enabled
        commentsUnderline?.isEnabled = enabled
        quotedTextUnderline?.isEnabled = enabled
        textSubstitutionsUnderline?.isEnabled = enabled

        headingsFontSize?.isEnabled = enabled
        mainTextFontSize?.isEnabled = enabled
        commentsFontSize?.isEnabled = enabled
        quotedTextFontSize?.isEnabled = enabled
        textSubstitutionsFontSize?.isEnabled = enabled

        // Enable button
        restoreSettingsButton?.isEnabled = !currentSet.isEqual(toPreferenceSet: defaultSet)
    }

    private final func updateFontStyleFromControl(withSender sender: AnyObject?,
                                                  optionType: IFSyntaxHighlightingOptionType,
                                                  bold boldButton: NSButton?,
                                                  italic italicButton: NSButton?) {
        if (sender === boldButton) || (sender === italicButton) {
            var result: UInt32 = 0

            if boldButton?.state == .on {
                result += 2
            }
            if italicButton?.state == .on {
                result += 1
            }

            currentSet.option(of: optionType).fontStyle = IFFontStyle(rawValue: result)!
        }
    }

    @IBAction func styleSetHasChanged(_ sender: Any?) {
        let sender = sender.map { $0 as AnyObject }

        // Update currentSet from preference pane controls
        do {
            let prefs = preferences

            if sender === fontFamily, let fontFamily {
                let regex = try! NSRegularExpression(pattern: "(.*) - (\\d+)$", options: [])
                let string = fontFamily.stringValue as NSString
                let match = regex.firstMatch(in: string as String,
                                             options: [],
                                             range: NSRange(location: 0, length: string.length))
                if let match {
                    let firstHalfRange = match.range(at: 1)
                    let secondHalfRange = match.range(at: 2)
                    currentSet.fontFamily = string.substring(with: firstHalfRange)
                    currentSet.fontSize = (string.substring(with: secondHalfRange) as NSString).intValue
                }
            }

            // Text section
            if sender === appTextSize, let appTextSize {
                prefs.appFontSizeMultiplierEnum = IFAppFontSize(rawValue: appTextSize.intValue)!
            }

            // Syntax highlighting section
            if sender === enableSyntaxHighlighting {
                currentSet.enableSyntaxHighlighting = (enableSyntaxHighlighting?.state == .on)
            }

            updateFontStyleFromControl(withSender: sender, optionType: .headings,          bold: headingsBold,          italic: headingsItalic)
            updateFontStyleFromControl(withSender: sender, optionType: .mainText,          bold: mainTextBold,          italic: mainTextItalic)
            updateFontStyleFromControl(withSender: sender, optionType: .comments,          bold: commentsBold,          italic: commentsItalic)
            updateFontStyleFromControl(withSender: sender, optionType: .quotedText,        bold: quotedTextBold,        italic: quotedTextItalic)
            updateFontStyleFromControl(withSender: sender, optionType: .textSubstitutions, bold: textSubstitutionsBold, italic: textSubstitutionsItalic)

            if sender === headingsUnderline          { currentSet.option(of: .headings).underline = headingsUnderline?.state == .on }
            if sender === mainTextUnderline          { currentSet.option(of: .mainText).underline = mainTextUnderline?.state == .on }
            if sender === commentsUnderline          { currentSet.option(of: .comments).underline = commentsUnderline?.state == .on }
            if sender === quotedTextUnderline        { currentSet.option(of: .quotedText).underline = quotedTextUnderline?.state == .on }
            if sender === textSubstitutionsUnderline { currentSet.option(of: .textSubstitutions).underline = textSubstitutionsUnderline?.state == .on }

            if sender === headingsFontSize, let headingsFontSize {
                currentSet.option(of: .headings).relativeFontSize = IFRelativeFontSize(rawValue: headingsFontSize.intValue)!
            }
            if sender === mainTextFontSize, let mainTextFontSize {
                currentSet.option(of: .mainText).relativeFontSize = IFRelativeFontSize(rawValue: mainTextFontSize.intValue)!
            }
            if sender === commentsFontSize, let commentsFontSize {
                currentSet.option(of: .comments).relativeFontSize = IFRelativeFontSize(rawValue: commentsFontSize.intValue)!
            }
            if sender === quotedTextFontSize, let quotedTextFontSize {
                currentSet.option(of: .quotedText).relativeFontSize = IFRelativeFontSize(rawValue: quotedTextFontSize.intValue)!
            }
            if sender === textSubstitutionsFontSize, let textSubstitutionsFontSize {
                currentSet.option(of: .textSubstitutions).relativeFontSize = IFRelativeFontSize(rawValue: textSubstitutionsFontSize.intValue)!
            }

            // Tab width section
            if sender === tabStopSlider, let tabStopSlider {
                currentSet.tabWidth = CGFloat(tabStopSlider.floatValue)
            }

            // Indenting section
            if sender === autoIndentAfterNewline { currentSet.autoIndentAfterNewline = (autoIndentAfterNewline?.state == .on) }
            if sender === autoSpaceTableColumns  { currentSet.autoSpaceTableColumns  = (autoSpaceTableColumns?.state == .on) }

            // Numbering section
            if sender === autoNumberSections     { currentSet.autoNumberSections     = (autoNumberSections?.state == .on) }
        }

        // Update dependent UI elements
        if sender === enableSyntaxHighlighting {
            updateDependentUIElements()
        }

        // Update application's preferences from currentSet, in a batch, so that the preferences only say they've
        // changed, which reloads currentSet from them, once all of it has been copied
        preferences.startBatchEditing()
        currentSet.update(preferences)
        preferences.endBatchEditing()
    }

    private final func setFontFamilyUI(_ fontFamilyName: String, fontSize points: Int32) {
        fontFamily?.stringValue = "\(fontFamilyName) - \(points)"
    }

    private final func setControls(fromFontStyle fontStyle: IFFontStyle,
                                   bold: NSButton?,
                                   italic: NSButton?) {
        bold?.state   = ((fontStyle.rawValue & 2) != 0) ? .on : .off
        italic?.state = ((fontStyle.rawValue & 1) != 0) ? .on : .off
    }

    func reflectCurrentPreferences() {
        let prefs = preferences

        // Update currentSet based on application's current preferences
        currentSet.updateSet(from: preferences)

        // Update preference pane UI elements from currentSet

        // Text section
        setFontFamilyUI(currentSet.fontFamily, fontSize: currentSet.fontSize)
        appTextSize?.intValue = prefs.appFontSizeMultiplierEnum.rawValue

        // Syntax highlighting section
        enableSyntaxHighlighting?.state = currentSet.enableSyntaxHighlighting ? .on : .off

        var option = currentSet.options[Int(IFSyntaxHighlightingOptionType.headings.rawValue)]
        setControls(fromFontStyle: option.fontStyle, bold: headingsBold, italic: headingsItalic)
        headingsUnderline?.state = option.underline ? .on : .off
        headingsFontSize?.intValue = option.relativeFontSize.rawValue

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)]
        setControls(fromFontStyle: option.fontStyle, bold: mainTextBold, italic: mainTextItalic)
        mainTextUnderline?.state = option.underline ? .on : .off
        mainTextFontSize?.intValue = option.relativeFontSize.rawValue

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.comments.rawValue)]
        setControls(fromFontStyle: option.fontStyle, bold: commentsBold, italic: commentsItalic)
        commentsUnderline?.state = option.underline ? .on : .off
        commentsFontSize?.intValue = option.relativeFontSize.rawValue

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.quotedText.rawValue)]
        setControls(fromFontStyle: option.fontStyle, bold: quotedTextBold, italic: quotedTextItalic)
        quotedTextUnderline?.state = option.underline ? .on : .off
        quotedTextFontSize?.intValue = option.relativeFontSize.rawValue

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.textSubstitutions.rawValue)]
        setControls(fromFontStyle: option.fontStyle, bold: textSubstitutionsBold, italic: textSubstitutionsItalic)
        textSubstitutionsUnderline?.state = option.underline ? .on : .off
        textSubstitutionsFontSize?.intValue = option.relativeFontSize.rawValue

        // Tab width section
        if let tabStopSlider {
            tabStopSlider.maxValue = Double(tabStopSlider.bounds.size.width - 12)
        }
        tabStopSlider?.floatValue = Float(prefs.tabWidth)

        // Indenting section
        autoIndentAfterNewline?.state = currentSet.autoIndentAfterNewline ? .on : .off
        autoSpaceTableColumns?.state = currentSet.autoSpaceTableColumns  ? .on : .off

        // Numbering section
        autoNumberSections?.state = currentSet.autoNumberSections     ? .on : .off

        // Update dependent elements
        updateDependentUIElements()

        // Update paper colour on preview
        previewView?.backgroundColor = prefs.sourcePaper.colour

        // Rehighlight the preview views
        if let tabStopStorage {
            IFSyntaxManager.preferencesChanged(tabStopStorage)
            IFSyntaxManager.highlightAll(tabStopStorage,
                                         forceUpdateTabs: true)
        }
        if let previewStorage {
            IFSyntaxManager.preferencesChanged(previewStorage)
            IFSyntaxManager.highlightAll(previewStorage,
                                         forceUpdateTabs: true)
        }
    }

    @objc private func viewWidthChanged(_ not: Notification) {
        // Update the maximum value of the tab slider
        if let tabStopSlider {
            tabStopSlider.maxValue = Double(tabStopSlider.bounds.size.width - 12)
        }
    }

    /// The font shown, or the system font of its size if its family isn't installed, as the source then uses
    private final func currentFont() -> NSFont {
        let font = NSFont(name: currentSet.fontFamily, size: CGFloat(currentSet.fontSize))
        return font ?? NSFont.systemFont(ofSize: CGFloat(currentSet.fontSize))
    }

    @IBAction private func showFontPicker(_ sender: Any?) {
        let fontPanel = NSFontPanel.shared
        let fontManager = NSFontManager.shared
        fontManager.action = #selector(selectFont(_:))
        fontManager.target = self
        fontManager.orderFrontFontPanel(fontPanel)

        fontManager.setSelectedFont(currentFont(), isMultiple: false)
    }

    @objc private func selectFont(_ sender: Any?) {
        let fontManager = NSFontManager.shared
        // Convert the font the Font panel was given, so that what wasn't changed in the panel is kept
        let selectedFont = fontManager.convert(currentFont())

        setFontFamilyUI(selectedFont.familyName ?? "", fontSize: Int32(selectedFont.pointSize))
        styleSetHasChanged(fontFamily)
    }

    @IBAction func restoreDefaultSettings(_ sender: Any?) {
        let alert = NSAlert()
        alert.addButton(withTitle: IFUtility.localizedString("Restore"))
        alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
        alert.messageText = IFUtility.localizedString("Reset the editing preferences?")
        alert.informativeText = IFUtility.localizedString("This action cannot be undone.")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            restoreDefaults()
        }
    }

    func restoreDefaults() {
        currentSet.resetSettings()

        preferences.startBatchEditing()
        currentSet.update(preferences)
        preferences.endBatchEditing()

        reflectCurrentPreferences()
    }
}
