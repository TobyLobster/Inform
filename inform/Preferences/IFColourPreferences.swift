//
//  IFColourPreferences.swift
//  Inform
//
//  Created by Toby Nelson in 2022
//  Translated from Objective-C in November 2026. The interface is still IFColourPreferences.h.
//

import Cocoa

@objc @implementation extension IFColourPreferences {
    /// The preferences the pane shows and sets
    private final var preferences: IFPreferences

    @IBOutlet private final var enableSyntaxColouringButton: NSButton?

    // Styles
    @IBOutlet private final var styleButton: NSPopUpButton?
    @IBOutlet private final var deleteStyleButton: NSButton?

    // Colours
    @IBOutlet private final var sourceColour: NSColorWell?
    @IBOutlet private final var extensionColor: NSColorWell?
    @IBOutlet private final var headingsColor: NSColorWell?
    @IBOutlet private final var mainTextColor: NSColorWell?
    @IBOutlet private final var commentsColor: NSColorWell?
    @IBOutlet private final var quotedTextColor: NSColorWell?
    @IBOutlet private final var textSubstitutionsColor: NSColorWell?
    @IBOutlet private final var restoreSettingsButton: NSButton?

    @IBOutlet private final var previewView: NSTextView?

    // Text storage for preview
    private final var previewStorage: NSTextStorage?

    // New theme sheet
    @IBOutlet private final var sheet: IFNewThemeWindow?

    // Data
    private final var enableSyntaxColouring = false
    private final var currentSet: IFColourTheme

    override convenience init() {
        self.init(preferences: IFPreferences.shared)
    }

    init(preferences thePreferences: IFPreferences) {
        preferences = thePreferences
        currentSet = IFColourTheme()
        super.init(nibName: "ColourPreferences")

        currentSet.updateSet(from: preferences)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reflectCurrentPreferences),
                                               name: .IFPreferencesEditingDidChange,
                                               object: preferences)

        // Create the preview
        let oldStorage = previewView?.textStorage
        let previewStorage = NSTextStorage(string: oldStorage?.string ?? "")
        self.previewStorage = previewStorage
        IFSyntaxManager.register(previewStorage,
                                 name: "Colour Preferences (preview)",
                                 type: .inform7,
                                 intelligence: nil,
                                 undoManager: nil)

        previewView?.layoutManager?.replaceTextStorage(previewStorage)

        reflectCurrentPreferences()
    }

    deinit {
        // The preferences window lets go of its panes on the main thread
        MainActor.assumeIsolated {
            if let previewStorage {
                IFSyntaxManager.unregisterTextStorage(previewStorage)
            }
        }
    }

    // MARK: - PreferencePane overrides

    public override var preferenceName: String {
        return "Colour"
    }

    public override var toolbarImage: NSImage? {
        return Bundle(for: type(of: self)).image(forResource: "App/paintpalette")
    }

    public override var tooltip: String? {
        return IFUtility.localizedString("Colour preferences tooltip")
    }

    public override var maxHeight: CGFloat {
        return .greatestFiniteMagnitude
    }

    public override var minHeight: CGFloat {
        return 322.0
    }

    // MARK: - Receiving data from/updating the interface

    private final func updateDependentUIElements() {
        let enabled = (enableSyntaxColouringButton?.state == .on)

        sourceColour?.isEnabled = enabled
        extensionColor?.isEnabled = enabled
        headingsColor?.isEnabled = enabled
        mainTextColor?.isEnabled = enabled
        commentsColor?.isEnabled = enabled
        quotedTextColor?.isEnabled = enabled
        textSubstitutionsColor?.isEnabled = enabled

        // Enable button
        restoreSettingsButton?.isEnabled = !currentSet.isEqualToDefault

        deleteStyleButton?.isEnabled = ((currentSet.flags?.int32Value ?? 0) & 1) == 1
    }

    @IBAction func newStyle(_ sender: Any?) {
        if sheet == nil {
            _ = Bundle.customLoadNib("NewThemeWindow",
                                     owner: self)
        }

        guard let sheet else { return }
        sheet.themeName = "Custom"
        let window = PreferenceController.shared.window
        window?.beginSheet(sheet) { returnCode in
            if returnCode == .OK {
                let name: String = sheet.themeName

                if !self.addThemeNamed(name) {
                    IFUtility.runAlertWarning(window,
                                              title: IFUtility.localizedString("Name already used"),
                                              informativeText: IFUtility.localizedString("The name you have chosen is already used. Try another name."))
                }
            }
        }
    }

    func addThemeNamed(_ name: String) -> Bool {
        let prefs = preferences

        // Try to add the theme
        let newTheme = currentSet.createDuplicateSet()
        newTheme.themeName = name

        // HACK: Set as deletable
        newTheme.flags = NSNumber(value: (newTheme.flags?.int32Value ?? 0) | 1)

        if !prefs.add(newTheme) {
            return false
        }

        // Select theme
        prefs.setCurrentTheme(name)

        // Update from the preferences based on the new theme
        reflectCurrentPreferences()
        return true
    }

    @IBAction func deleteStyle(_ sender: Any?) {
        // Ask for confirmation
        IFUtility.runAlertYesNoWindow(nil,
                                      title: IFUtility.localizedString("Are you sure?"),
                                      yes: IFUtility.localizedString("Delete"),
                                      no: IFUtility.localizedString("Cancel"),
                                      modalDelegate: self,
                                      didEnd: #selector(confirmDidEnd(_:returnCode:contextInfo:)),
                                      contextInfo: nil,
                                      destructiveIndex: 0,
                                      informativeText: IFUtility.localizedString("Do you want to delete the current theme?"))
    }

    @objc private func confirmDidEnd(_ sheet: NSWindow?,
                                     returnCode: NSApplication.ModalResponse,
                                     contextInfo: UnsafeMutableRawPointer?) {
        if returnCode == .alertFirstButtonReturn {
            deleteCurrentTheme()
        }
    }

    func deleteCurrentTheme() {
        let prefs = preferences
        if prefs.removeTheme(prefs.currentThemeName) {
            prefs.setCurrentTheme("Light Mode")
        }
    }

    @IBAction func differentThemeChosen(_ sender: Any?) {
        let selectedItem = styleButton?.selectedItem

        if let selectedItem {
            // Set the new name
            let currentThemeName = selectedItem.title

            // Get the theme from the preferences
            let prefs = preferences
            prefs.setCurrentTheme(currentThemeName)

            // Update from the preferences based on the new theme
            reflectCurrentPreferences()
        }
    }

    @IBAction func styleSetHasChanged(_ sender: Any?) {
        let sender = sender.map { $0 as AnyObject }

        // Update currentSet from preference pane
        do {
            if sender === enableSyntaxColouringButton {
                enableSyntaxColouring = (enableSyntaxColouringButton?.state == .on)
            }

            if sender === sourceColour, let sourceColour {
                currentSet.sourcePaper?.colour = sourceColour.color
            }
            if sender === extensionColor, let extensionColor {
                currentSet.extensionPaper?.colour = extensionColor.color
            }

            if sender === headingsColor, let headingsColor {
                currentSet.option(of: .headings).colour = headingsColor.color
            }
            if sender === mainTextColor, let mainTextColor {
                currentSet.option(of: .mainText).colour = mainTextColor.color
            }
            if sender === commentsColor, let commentsColor {
                currentSet.option(of: .comments).colour = commentsColor.color
            }
            if sender === quotedTextColor, let quotedTextColor {
                currentSet.option(of: .quotedText).colour = quotedTextColor.color
            }
            if sender === textSubstitutionsColor, let textSubstitutionsColor {
                currentSet.option(of: .textSubstitutions).colour = textSubstitutionsColor.color
            }
        }

        // Update dependent UI elements
        if sender === enableSyntaxColouringButton {
            updateDependentUIElements()
        }

        // Update application's preferences from currentSet, in a batch, so that the preferences only say they've
        // changed, which reloads currentSet from them, once all of it has been copied
        preferences.startBatchEditing()
        currentSet.update(preferences, fromSetWithEnable: enableSyntaxColouring)
        preferences.endBatchEditing()
    }

    @objc private func reflectCurrentPreferences() {
        // Get current theme settings from preferences
        let prefs = preferences
        let names = prefs.themeNames
        styleButton?.removeAllItems()
        styleButton?.addItems(withTitles: names)
        styleButton?.selectItem(withTitle: prefs.currentThemeName)

        enableSyntaxColouring = prefs.enableSyntaxColouring

        // Update currentSet based on application's current preferences, which gives it paper colours
        currentSet.updateSet(from: preferences)

        // Update preference pane UI elements from currentSet

        enableSyntaxColouringButton?.state = enableSyntaxColouring ? .on : .off
        sourceColour?.color = currentSet.sourcePaper!.colour
        extensionColor?.color = currentSet.extensionPaper!.colour

        var option = currentSet.options[Int(IFSyntaxHighlightingOptionType.headings.rawValue)]
        headingsColor?.color = option.colour

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)]
        mainTextColor?.color = option.colour

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.comments.rawValue)]
        commentsColor?.color = option.colour

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.quotedText.rawValue)]
        quotedTextColor?.color = option.colour

        option = currentSet.options[Int(IFSyntaxHighlightingOptionType.textSubstitutions.rawValue)]
        textSubstitutionsColor?.color = option.colour

        // Update dependent elements
        updateDependentUIElements()

        // Update paper colour on preview
        previewView?.backgroundColor = currentSet.sourcePaper!.colour

        // Rehighlight the preview views
        if let previewStorage {
            IFSyntaxManager.preferencesChanged(previewStorage)
            IFSyntaxManager.highlightAll(previewStorage,
                                         forceUpdateTabs: true)
        }
    }

    @IBAction func restoreDefaultSettings(_ sender: Any?) {
        let alert = NSAlert()
        alert.addButton(withTitle: IFUtility.localizedString("Restore"))
        alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
        alert.messageText = IFUtility.localizedString("Reset the current colours back to their original values?")
        alert.informativeText = IFUtility.localizedString("This action cannot be undone.")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            restoreDefaults()
        }
    }

    func restoreDefaults() {
        currentSet.resetSettings()

        enableSyntaxColouring = true

        preferences.startBatchEditing()
        currentSet.update(preferences, fromSetWithEnable: true)
        preferences.endBatchEditing()

        reflectCurrentPreferences()
    }
}
