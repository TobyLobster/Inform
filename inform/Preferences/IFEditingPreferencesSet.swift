//
//  IFEditingPreferencesSet.swift
//  Inform
//
//  Created by Toby Nelson in 2014
//  Translated from Objective-C in November 2026. The interface is still IFEditingPreferencesSet.h.
//

import Cocoa

@objc @implementation extension IFSyntaxHighlightingOption {

    var fontStyle: IFFontStyle
    var underline: Bool
    var relativeFontSize: IFRelativeFontSize

    override init() {
        self.fontStyle        = .regular
        self.underline        = false
        self.relativeFontSize = .fontSizeNormal
        super.init()
    }
}

@objc @implementation extension IFEditingPreferencesSet {

    var enableSyntaxHighlighting: Bool
    var fontFamily: String
    var fontSize: Int32

    var options: [IFSyntaxHighlightingOption]

    var tabWidth: CGFloat
    var autoIndentAfterNewline: Bool
    var autoSpaceTableColumns: Bool
    var autoNumberSections: Bool

    override init() {
        var options: [IFSyntaxHighlightingOption] = []

        options.insert(IFSyntaxHighlightingOption(), at: Int(IFSyntaxHighlightingOptionType.headings.rawValue))
        options.insert(IFSyntaxHighlightingOption(), at: Int(IFSyntaxHighlightingOptionType.mainText.rawValue))
        options.insert(IFSyntaxHighlightingOption(), at: Int(IFSyntaxHighlightingOptionType.comments.rawValue))
        options.insert(IFSyntaxHighlightingOption(), at: Int(IFSyntaxHighlightingOptionType.quotedText.rawValue))
        options.insert(IFSyntaxHighlightingOption(), at: Int(IFSyntaxHighlightingOptionType.textSubstitutions.rawValue))
        self.options = options

        // Each is set by resetSettings, below
        enableSyntaxHighlighting = false
        fontFamily = ""
        fontSize = 0
        tabWidth = 0
        autoIndentAfterNewline = false
        autoSpaceTableColumns = false
        autoNumberSections = false
        super.init()

        resetSettings()
    }

    func resetSettings() {
        fontFamily = "Lucida Grande"
        fontSize = 12

        // Syntax highlighting section
        enableSyntaxHighlighting = true

        tabWidth = 24.0

        // Indenting
        autoIndentAfterNewline  = true
        autoSpaceTableColumns   = true

        // Numbering
        autoNumberSections      = true

        // Headings
        var option = options[Int(IFSyntaxHighlightingOptionType.headings.rawValue)]
        option.fontStyle = .regular
        option.relativeFontSize = .fontSizePlus10
        option.underline = true

        // Main text
        option = options[Int(IFSyntaxHighlightingOptionType.mainText.rawValue)]
        option.fontStyle = .regular
        option.relativeFontSize = .fontSizeNormal
        option.underline = false

        // Comments
        option = options[Int(IFSyntaxHighlightingOptionType.comments.rawValue)]
        option.fontStyle = .regular
        option.relativeFontSize = .fontSizeNormal
        option.underline = false

        // Quoted text
        option = options[Int(IFSyntaxHighlightingOptionType.quotedText.rawValue)]
        option.fontStyle = .regular
        option.relativeFontSize = .fontSizeNormal
        option.underline = false

        // Text substitutions
        option = options[Int(IFSyntaxHighlightingOptionType.textSubstitutions.rawValue)]
        option.fontStyle = .regular
        option.relativeFontSize = .fontSizeNormal
        option.underline = false
    }

    func updateAppPreferencesFromSet() {
        let prefs = IFPreferences.shared

        // Text section
        prefs.sourceFontFamily = fontFamily
        prefs.sourceFontSize = CGFloat(fontSize)

        // Syntax highlighting section
        prefs.enableSyntaxHighlighting = enableSyntaxHighlighting

        for optionIndex in IFSyntaxHighlightingOptionType.headings.rawValue..<IFSyntaxHighlightingOptionType.count.rawValue {
            let option = options[Int(optionIndex)]
            let optionType = IFSyntaxHighlightingOptionType(rawValue: optionIndex)!
            prefs.setSourceFontStyle(option.fontStyle, for: optionType)
            prefs.setSourceUnderline(option.underline, for: optionType)
            prefs.setSourceRelativeFontSize(option.relativeFontSize, for: optionType)
        }

        // Tab width section
        prefs.tabWidth = tabWidth

        // Indenting section
        prefs.indentAfterNewline = autoIndentAfterNewline
        prefs.elasticTabs = autoSpaceTableColumns

        // Numbering section
        prefs.autoNumberSections = autoNumberSections
    }

    @objc(updateSetFromAppPreferences)
    func updateFromAppPreferences() {
        let prefs = IFPreferences.shared

        // Text section
        fontFamily          = prefs.sourceFontFamily
        // A size that doesn't fit an int, from a damaged preferences file, is clamped: Swift's conversion would stop
        // the app, and C's was undefined
        let sourceFontSize  = prefs.sourceFontSize
        fontSize            = sourceFontSize.isNaN ? 0 : Int32(min(max(sourceFontSize, CGFloat(Int32.min)), CGFloat(Int32.max)))

        // Syntax highlighting section
        enableSyntaxHighlighting = prefs.enableSyntaxHighlighting
        for optionIndex in IFSyntaxHighlightingOptionType.headings.rawValue..<IFSyntaxHighlightingOptionType.count.rawValue {
            let option = options[Int(optionIndex)]
            let optionType = IFSyntaxHighlightingOptionType(rawValue: optionIndex)!
            option.fontStyle        = prefs.sourceFontStyle(for: optionType)
            option.underline        = prefs.sourceUnderline(for: optionType)
            option.relativeFontSize = prefs.sourceRelativeFontSize(for: optionType)
        }

        // Tab width section
        tabWidth = prefs.tabWidth

        // Indenting section
        autoIndentAfterNewline = prefs.indentAfterNewline
        autoSpaceTableColumns = prefs.elasticTabs

        // Numbering section
        autoNumberSections = prefs.autoNumberSections
    }

    @objc(optionOfType:)
    func option(of type: IFSyntaxHighlightingOptionType) -> IFSyntaxHighlightingOption {
        return options[Int(type.rawValue)]
    }

    func isEqual(toPreferenceSet set: IFEditingPreferencesSet) -> Bool {
        if !(fontFamily as NSString).isEqual(to: set.fontFamily) {
            return false
        }
        if fontSize != set.fontSize {
            return false
        }
        if enableSyntaxHighlighting != set.enableSyntaxHighlighting {
            return false
        }
        for optionIndex in IFSyntaxHighlightingOptionType.headings.rawValue..<IFSyntaxHighlightingOptionType.count.rawValue {
            let option1 = options[Int(optionIndex)]
            let option2 = set.options[Int(optionIndex)]

            if option1.fontStyle != option2.fontStyle {
                return false
            }
            if option1.underline != option2.underline {
                return false
            }
            if option1.relativeFontSize != option2.relativeFontSize {
                return false
            }
        }
        if tabWidth != set.tabWidth {
            return false
        }
        if autoIndentAfterNewline != set.autoIndentAfterNewline {
            return false
        }
        if autoSpaceTableColumns != set.autoSpaceTableColumns {
            return false
        }
        if autoNumberSections != set.autoNumberSections {
            return false
        }

        return true
    }
}
