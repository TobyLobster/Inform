//
//  IFPreferences.swift
//  Inform
//
//  Created by Andrew Hunter on 02/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFPreferences.h.
//

import Cocoa

private let IFPreferencesHeadings          = "Headings"
private let IFPreferencesMainText          = "MainText"
private let IFPreferencesComments          = "Comments"
private let IFPreferencesQuotedText        = "QuotedText"
private let IFPreferencesTextSubstitutions = "TextSubstitutions"

@MainActor private let sharedPrefs = IFPreferences()

private extension IFSyntaxHighlightingOptionType {
    /// The kind of text's place in a theme's options
    var index: Int { Int(rawValue) }
}

private extension IFSyntaxStyle {
    /// The style's place in the styles
    var index: Int { Int(rawValue) }
}

@objc @implementation extension IFPreferences {
    /// Where the preferences dictionary is kept
    private final let userDefaults: UserDefaults
    /// The preferences dictionary
    private final let preferences: NSMutableDictionary

    // Notification flag
    private final var batchEditingPreferences: Bool
    /// Whether a preference has changed in the batch
    private final var batchHasChanges: Bool
    /// Each kind of change in the batch, once, in the order first made
    private final var batchNotificationTypes: [NSNotification.Name]
    private final var notificationString: NSNotification.Name?

    // Caches
    /// Maps 'font types' to fonts
    private final var cacheFontSet: [String: NSFont] = [:]
    /// Maps styles to fonts
    private final var cacheFontStyles: [NSFont] = []
    /// Maps styles to colours
    private final var cacheColours: [NSColor] = []
    /// Maps styles to underlines
    private final var cacheUnderlines: [Bool] = []

    /// The array of actual styles (array of attribute dictionaries)
    private final var _styles: [NSMutableDictionary] = []

    // Themes
    private final var themes: [IFColourTheme] = []

    // Defaults
    private final let defaultEditingPreferences: IFEditingPreferencesSet

    // MARK: - Constructing the object

    @objc(sharedPreferences)
    class var shared: IFPreferences {
        return sharedPrefs
    }

    override convenience init() {
        self.init(userDefaults: .standard)
    }

    init(userDefaults theUserDefaults: UserDefaults) {
        userDefaults = theUserDefaults
        if let stored = userDefaults.object(forKey: IFPreferencesDefault) as? NSDictionary {
            preferences = stored.mutableCopy() as! NSMutableDictionary
        } else {
            // None, or damaged
            preferences = NSMutableDictionary()
        }

        batchEditingPreferences = false
        batchHasChanges = false
        batchNotificationTypes = []

        defaultEditingPreferences = IFEditingPreferencesSet()
        super.init()

        if let result = getPreferenceThemes() {
            themes = result
        } else {
            themes = []
        }

        recalculateStyles()
    }

    // MARK: - Preference change notifications

    func preferencesHaveChanged() {
        if !batchEditingPreferences {
            // Update the user defaults
            userDefaults.set(preferences.copy(), forKey: IFPreferencesDefault)
            recalculateStyles()

            // Send a notification
            if let notificationString {
                NotificationCenter.default.post(name: notificationString, object: self)
            }
        } else {
            batchHasChanges = true
            if let notificationString, !batchNotificationTypes.contains(notificationString) {
                batchNotificationTypes.append(notificationString)
            }
        }
        notificationString = nil
    }

    // MARK: - batch editing of preferences

    func startBatchEditing() {
        precondition(batchEditingPreferences == false, "error updating preferences (start batch)")
        batchEditingPreferences = true
        batchHasChanges = false
        batchNotificationTypes.removeAll()
    }

    func endBatchEditing() {
        precondition(batchEditingPreferences == true, "error updating preferences (end batch)")
        batchEditingPreferences = false
        let hasChanges = batchHasChanges
        let notifications = batchNotificationTypes
        batchHasChanges = false
        batchNotificationTypes.removeAll()
        notificationString = nil

        // Write the preferences and recalculate the styles once, then tell of each kind of change once, so that
        // (say) the source views are re-highlighted once
        guard hasChanges else { return }
        userDefaults.set(preferences.copy(), forKey: IFPreferencesDefault)
        recalculateStyles()
        for notification in notifications {
            NotificationCenter.default.post(name: notification, object: self)
        }
    }

    // MARK: - Helper methods

    private final func getPreference(_ key: String, default defaultValue: Any?) -> Any? {
        if let result = preferences[key] {
            return result
        }
        return defaultValue
    }

    private final func setPreference(_ key: String, value: NSObject?, notification: NSNotification.Name?) {
        if !((preferences[key] as? NSObject)?.isEqual(to: value) ?? false) {
            if let value {
                preferences[key] = value
            } else {
                preferences.removeObject(forKey: key)
            }

            notificationString = notification
            preferencesHaveChanged()
        }
    }

    private final func setPreferenceString(_ key: String, value: String?, notification: NSNotification.Name?) {
        setPreference(key, value: value as NSString?, notification: notification)
    }

    private final func getPreferenceString(_ key: String, default defaultValue: String) -> String {
        guard let value = getPreference(key, default: defaultValue) as? String else {
            // From a damaged preferences file
            return defaultValue
        }
        return value
    }

    /// A number, or text as `defaults write` writes it: both answer intValue, doubleValue and boolValue
    private final func getPreferenceNumber(_ key: String, default defaultValue: NSNumber) -> NSObject {
        switch getPreference(key, default: defaultValue) {
        case let number as NSNumber:
            return number
        case let text as NSString:
            return text
        default:
            // From a damaged preferences file
            return defaultValue
        }
    }

    private final func setPreferenceInt(_ key: String, value: Int32, notification: NSNotification.Name?) {
        setPreference(key, value: NSNumber(value: value), notification: notification)
    }

    private final func getPreferenceInt(_ key: String, default defaultValue: Int32) -> Int32 {
        let value = getPreferenceNumber(key, default: NSNumber(value: defaultValue))
        if let text = value as? NSString {
            return text.intValue
        }
        return (value as! NSNumber).int32Value
    }

    private final func setPreferenceDouble(_ key: String, value: Double, notification: NSNotification.Name?) {
        setPreference(key, value: NSNumber(value: value), notification: notification)
    }

    private final func getPreferenceDouble(_ key: String, default defaultValue: Double) -> Double {
        let value = getPreferenceNumber(key, default: NSNumber(value: defaultValue))
        if let text = value as? NSString {
            return text.doubleValue
        }
        return (value as! NSNumber).doubleValue
    }

    private final func setPreferenceThemes(withNotification notification: NSNotification.Name?) {
        let nonMutableArray = NSArray(array: themes)
        let theData = try? NSKeyedArchiver.archivedData(withRootObject: nonMutableArray,
                                                        requiringSecureCoding: true)
        setPreference("themes", value: theData as NSData?, notification: notification)
    }

    private final func removeIllegalEntries(_ array: [IFColourTheme]) -> [IFColourTheme] {
        var result: [IFColourTheme] = []
        for theme in array {
            if theme.themeName == nil ||
               theme.sourcePaper == nil ||
               theme.extensionPaper == nil ||
               theme.flags == nil {
                continue
            }

            if theme.options.count < IFSyntaxHighlightingOptionType.count.index {
                continue
            }

            result.append(theme)
        }
        return result
    }

    private final func getPreferenceThemes() -> [IFColourTheme]? {
        guard let value = getPreference("themes", default: nil) else {
            return nil
        }
        guard let theData = value as? Data else {
            NSLog("The colour themes in the preferences aren't data")
            return nil
        }

        let classes: [AnyClass] = [NSString.self,
                                   NSColor.self,
                                   IFColourTheme.self,
                                   IFSyntaxColouringOption.self,
                                   NSArray.self,
                                   NSMutableArray.self,
                                   NSNumber.self,
                                   NSMutableData.self,
                                   NSDictionary.self,
                                   NSDate.self,
                                   NSValue.self,
                                   NSNull.self]
        guard let unarchived = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: theData) else {
            // Unreadable
            return removeIllegalEntries([])
        }
        guard let array = unarchived as? [IFColourTheme] else {
            NSLog("The colour themes in the preferences aren't an array of themes")
            return nil
        }
        return removeIllegalEntries(array)
    }

    private final func getThemeIndex(_ name: String?) -> Int {
        for i in 0..<themes.count {
            let theme = themes[i]
            if let name, (name as NSString).isEqual(toStringCaseInsensitive: theme.themeName ?? "") {
                return i
            }
        }
        return -1
    }

    func getCurrentTheme() -> IFColourTheme {
        if themes.count == 0 {
            resetDefaultThemes()
        }
        precondition(themes.count > 0)

        var i = getThemeIndex(currentThemeName)
        if i < 0 {
            i = 0
            // As setting currentThemeName does, with a name that Swift's types allow to be nil
            setPreferenceString("currentThemeName",
                                value: themes[i].themeName,
                                notification: .IFPreferencesEditingDidChange)
        }
        return themes[i]
    }

    func setCurrentTheme(_ name: String) -> Bool {
        // if name doesn't exist, fail
        let result = getThemeIndex(name)
        if result < 0 {
            return false
        }

        // Setting the name writes the preferences and tells of the change, if it changes
        currentThemeName = name
        return true
    }

    var themeNames: [String] {
        return themes.compactMap { $0.themeName }
    }

    @objc(addTheme:)
    func add(_ theme: IFColourTheme) -> Bool {
        // If theme name already exists, fail
        if getThemeIndex(theme.themeName) >= 0 {
            return false
        }

        // Setting the themes writes the preferences and tells of the change
        themes.append(theme)
        setPreferenceThemes(withNotification: .IFPreferencesEditingDidChange)
        return true
    }

    func removeTheme(_ themeName: String) -> Bool {
        let index = getThemeIndex(themeName)
        if index < 0 {
            return false
        }
        let theme = themes[index]
        if ((theme.flags?.int32Value ?? 0) & 1) == 0 {
            // Not deletable
            return false
        }

        // Setting the themes writes the preferences and tells of the change
        themes.remove(at: index)
        setPreferenceThemes(withNotification: .IFPreferencesEditingDidChange)
        return true
    }

    func setDarkMode(_ isDarkMode: Bool) {
        let currentThemeName = self.currentThemeName as NSString
        if currentThemeName.isEqual(to: "Light Mode") {
            if isDarkMode {
                _ = setCurrentTheme("Dark Mode")
            }
        }
        else if currentThemeName.isEqual(to: "Dark Mode") {
            if !isDarkMode {
                _ = setCurrentTheme("Light Mode")
            }
        }
    }

    private final func setPreferenceBool(_ key: String, value: Bool, notification: NSNotification.Name?) {
        setPreference(key, value: NSNumber(value: value), notification: notification)
    }

    private final func getPreferenceBool(_ key: String, default defaultValue: Bool) -> Bool {
        let value = getPreferenceNumber(key, default: NSNumber(value: defaultValue))
        if let text = value as? NSString {
            return text.boolValue
        }
        return (value as! NSNumber).boolValue
    }

    private final func byteColour(_ red: Int, _ green: Int, _ blue: Int) -> NSColor {
        return NSColor(deviceRed: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    // MARK: - Editing preferences

    private final func resetDefaultThemes() {
        themes = []

        // Create light theme
        let light = IFColourTheme()
        light.themeName           = "Light Mode"
        light.sourcePaper         = IFSyntaxColouringOption(colour: byteColour(255, 255, 255))
        light.extensionPaper      = IFSyntaxColouringOption(colour: byteColour(255, 255, 228))
        light.flags               = NSNumber(value: 0 as Int32)
        light.options[IFSyntaxHighlightingOptionType.headings.index].colour          = byteColour(230,  61,  66)
        light.options[IFSyntaxHighlightingOptionType.mainText.index].colour          = byteColour(  0,   0,   0)
        light.options[IFSyntaxHighlightingOptionType.comments.index].colour          = byteColour( 70, 170,  37)
        light.options[IFSyntaxHighlightingOptionType.quotedText.index].colour        = byteColour( 65, 131, 250)
        light.options[IFSyntaxHighlightingOptionType.textSubstitutions.index].colour = byteColour(232,  60, 249)

        for option in light.options {
            option.defaultColour = option.colour.copy() as! NSColor
        }

        themes.append(light)

        // Create dark theme
        let dark = IFColourTheme()
        dark.themeName           = "Dark Mode"
        dark.sourcePaper         = IFSyntaxColouringOption(colour: byteColour(  0,   0,   0))
        dark.extensionPaper      = IFSyntaxColouringOption(colour: byteColour( 66,  13,   0))
        dark.flags               = NSNumber(value: 0 as Int32)
        dark.options[IFSyntaxHighlightingOptionType.headings.index].colour          = byteColour(234, 108, 105)
        dark.options[IFSyntaxHighlightingOptionType.mainText.index].colour          = byteColour(255, 255, 255)
        dark.options[IFSyntaxHighlightingOptionType.comments.index].colour          = byteColour(149, 249, 156)
        dark.options[IFSyntaxHighlightingOptionType.quotedText.index].colour        = byteColour( 93, 213, 253)
        dark.options[IFSyntaxHighlightingOptionType.textSubstitutions.index].colour = byteColour(238, 139, 231)

        for option in dark.options {
            option.defaultColour = option.colour.copy() as! NSColor
        }
        themes.append(dark)

        // Create Seven Seas theme
        let sevenSeas = IFColourTheme()
        sevenSeas.themeName           = "Seven Seas"
        sevenSeas.sourcePaper         = IFSyntaxColouringOption(colour: byteColour(233, 233, 255))
        sevenSeas.extensionPaper      = IFSyntaxColouringOption(colour: byteColour(233, 255, 233))
        sevenSeas.flags               = NSNumber(value: 0 as Int32)
        sevenSeas.options[IFSyntaxHighlightingOptionType.headings.index].colour          = byteColour( 52,   0, 255)
        sevenSeas.options[IFSyntaxHighlightingOptionType.mainText.index].colour          = byteColour(  0,   0, 100)
        sevenSeas.options[IFSyntaxHighlightingOptionType.comments.index].colour          = byteColour(109, 167, 233)
        sevenSeas.options[IFSyntaxHighlightingOptionType.quotedText.index].colour        = byteColour(  0, 106, 255)
        sevenSeas.options[IFSyntaxHighlightingOptionType.textSubstitutions.index].colour = byteColour( 45, 108, 208)

        for option in sevenSeas.options {
            option.defaultColour = option.colour.copy() as! NSColor
        }
        themes.append(sevenSeas)

        // Create traditional theme (the original colours)
        let traditional = IFColourTheme()
        traditional.themeName           = "Traditional"
        traditional.sourcePaper         = IFSyntaxColouringOption(colour: byteColour(255, 255, 255))
        traditional.extensionPaper      = IFSyntaxColouringOption(colour: NSColor(deviceRed: 1.0, green: 1.0, blue: 0.9, alpha: 1.0))
        traditional.flags               = NSNumber(value: 0 as Int32)
        traditional.options[IFSyntaxHighlightingOptionType.headings.index].colour          = NSColor(deviceRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        traditional.options[IFSyntaxHighlightingOptionType.mainText.index].colour          = NSColor(deviceRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        traditional.options[IFSyntaxHighlightingOptionType.comments.index].colour          = NSColor(deviceRed: 0.14, green: 0.43, blue: 0.14, alpha: 1.0)
        traditional.options[IFSyntaxHighlightingOptionType.quotedText.index].colour        = NSColor(deviceRed: 0.0, green: 0.3, blue: 0.6, alpha: 1.0)
        traditional.options[IFSyntaxHighlightingOptionType.textSubstitutions.index].colour = NSColor(deviceRed: 0.3, green: 0.3, blue: 1.0, alpha: 1.0)

        for option in traditional.options {
            option.defaultColour = option.colour.copy() as! NSColor
        }
        themes.append(traditional)

        setPreferenceThemes(withNotification: .IFPreferencesEditingDidChange)
    }

    var currentThemeName: String {
        get {
            return getPreferenceString("currentThemeName", default: "Light Mode")
        }
        set {
            setPreferenceString("currentThemeName", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var sourceFontFamily: String {
        get {
            return getPreferenceString("sourceFontFamily", default: defaultEditingPreferences.fontFamily)
        }
        set {
            setPreferenceString("sourceFontFamily", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var sourceFontSize: CGFloat {
        get {
            return getPreferenceDouble("sourceFontSize", default: Double(defaultEditingPreferences.fontSize))
        }
        set {
            setPreferenceDouble("sourceFontSize", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var appFontSizeMultiplier: CGFloat {
        let appFontSize = appFontSizeMultiplierEnum
        switch appFontSize {
        case .minus100: return 0.625 + 0.75 * 0 / 8
        case .minus75:  return 0.625 + 0.75 * 1 / 8
        case .minus50:  return 0.625 + 0.75 * 2 / 8
        case .minus25:  return 0.625 + 0.75 * 3 / 8
        case .normal:   return 0.625 + 0.75 * 4 / 8
        case .plus25:   return 0.625 + 0.75 * 5 / 8
        case .plus50:   return 0.625 + 0.75 * 6 / 8
        case .plus75:   return 0.625 + 0.75 * 7 / 8
        case .plus100:  return 0.625 + 0.75 * 8 / 8
        @unknown default: break
        }
        // A size that isn't one of them, from a damaged preferences file, is the normal size
        return 0.625 + 0.75 * 4 / 8
    }

    var appFontSizeMultiplierEnum: IFAppFontSize {
        get {
            return IFAppFontSize(rawValue: getPreferenceInt("appFontSizeMultiplierFineEnum", default: IFAppFontSize.normal.rawValue))!
        }
        set {
            setPreferenceInt("appFontSizeMultiplierFineEnum", value: newValue.rawValue, notification: .IFPreferencesAppFontSizeDidChange)
        }
    }

    var tabWidth: CGFloat {
        get {
            return getPreferenceDouble("tabWidth", default: defaultEditingPreferences.tabWidth)
        }
        set {
            setPreferenceDouble("tabWidth", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    @objc(sourceFontStyleForOptionType:)
    func sourceFontStyle(for optionType: IFSyntaxHighlightingOptionType) -> IFFontStyle {
        let key = "sourceFontStyle\(optionType.rawValue)"
        let option = defaultEditingPreferences.options[optionType.index]
        let result = getPreferenceInt(key, default: Int32(bitPattern: option.fontStyle.rawValue))
        return IFFontStyle(rawValue: UInt32(bitPattern: result))!
    }

    @objc(setSourceFontStyle:forOptionType:)
    func setSourceFontStyle(_ style: IFFontStyle, for optionType: IFSyntaxHighlightingOptionType) {
        let key = "sourceFontStyle\(optionType.rawValue)"
        setPreferenceInt(key, value: Int32(bitPattern: style.rawValue), notification: .IFPreferencesEditingDidChange)
    }

    @objc(sourceRelativeFontSizeForOptionType:)
    func sourceRelativeFontSize(for optionType: IFSyntaxHighlightingOptionType) -> IFRelativeFontSize {
        let key = "sourceRelativeFontSize\(optionType.rawValue)"
        let option = defaultEditingPreferences.options[optionType.index]
        return IFRelativeFontSize(rawValue: getPreferenceInt(key, default: option.relativeFontSize.rawValue))!
    }

    @objc(setSourceRelativeFontSize:forOptionType:)
    func setSourceRelativeFontSize(_ size: IFRelativeFontSize, for optionType: IFSyntaxHighlightingOptionType) {
        let key = "sourceRelativeFontSize\(optionType.rawValue)"
        setPreferenceInt(key, value: size.rawValue, notification: .IFPreferencesEditingDidChange)
    }

    var sourcePaper: IFSyntaxColouringOption {
        get {
            let theme = getCurrentTheme()
            return theme.sourcePaper!
        }
        set {
            let theme = getCurrentTheme()
            theme.sourcePaper = (newValue.copy() as! IFSyntaxColouringOption)
            setPreferenceThemes(withNotification: .IFPreferencesEditingDidChange)
        }
    }

    var extensionPaper: IFSyntaxColouringOption {
        get {
            let theme = getCurrentTheme()
            return theme.extensionPaper!
        }
        set {
            let theme = getCurrentTheme()
            theme.extensionPaper = (newValue.copy() as! IFSyntaxColouringOption)
            setPreferenceThemes(withNotification: .IFPreferencesEditingDidChange)
        }
    }

    @objc(sourcePaperForOptionType:)
    func sourcePaper(for optionType: IFSyntaxHighlightingOptionType) -> IFSyntaxColouringOption {
        let theme = getCurrentTheme()

        let option = theme.options[optionType.index]
        return option
    }

    @objc(setSourceColour:forOptionType:)
    func setSourceColour(_ colour: NSColor, for optionType: IFSyntaxHighlightingOptionType) {
        let theme = getCurrentTheme()
        let option = theme.options[optionType.index]
        option.colour = colour

        setPreferenceThemes(withNotification: .IFPreferencesEditingDidChange)
    }

    @objc(sourceUnderlineForOptionType:)
    func sourceUnderline(for optionType: IFSyntaxHighlightingOptionType) -> Bool {
        let key = "sourceUnderline\(optionType.rawValue)"
        let option = defaultEditingPreferences.options[optionType.index]
        return getPreferenceBool(key, default: option.underline)
    }

    @objc(setSourceUnderline:forOptionType:)
    func setSourceUnderline(_ underline: Bool, for optionType: IFSyntaxHighlightingOptionType) {
        let key = "sourceUnderline\(optionType.rawValue)"
        setPreferenceBool(key, value: underline, notification: .IFPreferencesEditingDidChange)
    }

    var enableSyntaxHighlighting: Bool {
        get {
            return getPreferenceBool("enableSyntaxHighlighting", default: defaultEditingPreferences.enableSyntaxHighlighting)
        }
        set {
            setPreferenceBool("enableSyntaxHighlighting", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var enableSyntaxColouring: Bool {
        get {
            return getPreferenceBool("enableSyntaxColouring", default: true)
        }
        set {
            setPreferenceBool("enableSyntaxColouring", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var elasticTabs: Bool {
        get {
            return getPreferenceBool("elasticTabs", default: defaultEditingPreferences.autoSpaceTableColumns)
        }
        set {
            setPreferenceBool("elasticTabs", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var indentAfterNewline: Bool {
        get {
            return getPreferenceBool("indentAfterNewline", default: defaultEditingPreferences.autoIndentAfterNewline)
        }
        set {
            setPreferenceBool("indentAfterNewline", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    var autoNumberSections: Bool {
        get {
            return getPreferenceBool("autoNumberSections", default: defaultEditingPreferences.autoNumberSections)
        }
        set {
            setPreferenceBool("autoNumberSections", value: newValue, notification: .IFPreferencesEditingDidChange)
        }
    }

    private final func font(withFamily family: String,
                            traits: NSFontTraitMask,
                            weight: Int,
                            size: CGFloat) -> NSFont {
        var font = NSFontManager.shared.font(withFamily: family,
                                             traits: traits,
                                             weight: weight,
                                             size: size)
        if font == nil {
            font = NSFontManager.shared.font(withFamily: family,
                                             traits: [],
                                             weight: weight,
                                             size: size)
        }

        if font == nil {
            font = NSFontManager.shared.font(withFamily: family,
                                             traits: traits,
                                             weight: 5,
                                             size: size)
        }

        if font == nil {
            font = NSFontManager.shared.font(withFamily: family,
                                             traits: [],
                                             weight: 5,
                                             size: size)
        }

        if font == nil {
            font = NSFont.systemFont(ofSize: size)
        }

        return font!
    }

    private final func font(for optionType: IFSyntaxHighlightingOptionType) -> NSFont {
        let style = sourceFontStyle(for: optionType)

        var mask: NSFontTraitMask = []
        if      style == .regular     { mask = [] }
        else if style == .italic      { mask = .italicFontMask }
        else if style == .bold        { mask = .boldFontMask }
        else if style == .boldItalic  { mask = [.boldFontMask, .italicFontMask] }

        var fontSize = sourceFontSize
        switch sourceRelativeFontSize(for: optionType) {
        case .fontSizeMinus30: fontSize *= CGFloat(0.7 as Float)
        case .fontSizeMinus20: fontSize *= CGFloat(0.8 as Float)
        case .fontSizeMinus10: fontSize *= CGFloat(0.9 as Float)
        case .fontSizePlus10:  fontSize *= CGFloat(1.1 as Float)
        case .fontSizePlus20:  fontSize *= CGFloat(1.2 as Float)
        case .fontSizePlus30:  fontSize *= CGFloat(1.3 as Float)
        case .fontSizeNormal:
            break
        @unknown default:
            break
        }

        let result = font(withFamily: sourceFontFamily,
                          traits: mask,
                          weight: ((style == .bold) || (style == .boldItalic)) ? 9 : 5,
                          size: fontSize)

        // A family with no italic face gives the upright one, as Lucida Grande, the default, does, so it's slanted
        // instead, as an oblique face would be
        if mask.contains(.italicFontMask) && !NSFontManager.shared.traits(of: result).contains(.italicFontMask) {
            let size = result.pointSize
            let slant = AffineTransform(m11: size, m12: 0, m21: size * 0.2, m22: size, tX: 0, tY: 0)
            return NSFont(descriptor: result.fontDescriptor, textTransform: slant) ?? result
        }
        return result
    }

    func recalculateStyles() {
        // Deallocate the caches if they're currently allocated
        _styles = []

        // Cache of fonts we will use
        cacheFontSet = [
            IFPreferencesHeadings:          font(for: .headings),
            IFPreferencesMainText:          font(for: .mainText),
            IFPreferencesComments:          font(for: .comments),
            IFPreferencesQuotedText:        font(for: .quotedText),
            IFPreferencesTextSubstitutions: font(for: .textSubstitutions),
        ]

        // Map font styles to syntax styles
        cacheFontStyles = []
        cacheColours = []
        cacheUnderlines = []

        // Default is just the base font
        let baseFont = cacheFontSet[IFPreferencesMainText]!
        let black = NSColor.black
        for _ in 0..<256 {
            cacheFontStyles.append(baseFont)
            cacheColours.append(black)
            cacheUnderlines.append(false)
        }

        //
        // Set fonts for each style
        //

        // Inform 6
        cacheFontStyles[IFSyntaxStyle.property.index] = cacheFontSet[IFPreferencesQuotedText]!
        cacheFontStyles[IFSyntaxStyle.assembly.index] = cacheFontSet[IFPreferencesQuotedText]!
        cacheFontStyles[IFSyntaxStyle.escapeCharacter.index] = cacheFontSet[IFPreferencesQuotedText]!

        // Inform 7
        cacheFontStyles[IFSyntaxStyle.title.index] = cacheFontSet[IFPreferencesHeadings]!
        cacheFontStyles[IFSyntaxStyle.heading.index] = cacheFontSet[IFPreferencesHeadings]!
        cacheFontStyles[IFSyntaxStyle.naturalInform.index] = cacheFontSet[IFPreferencesMainText]!
        cacheFontStyles[IFSyntaxStyle.comment.index] = cacheFontSet[IFPreferencesComments]!
        cacheFontStyles[IFSyntaxStyle.gameText.index] = cacheFontSet[IFPreferencesQuotedText]!
        cacheFontStyles[IFSyntaxStyle.substitution.index] = cacheFontSet[IFPreferencesTextSubstitutions]!

        //
        // Set colours for each style
        //

        // Inform 6
        cacheColours[IFSyntaxStyle().index] = NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        cacheColours[IFSyntaxStyle.string.index] = NSColor(deviceRed: 0.53, green: 3*0.08, blue: 3*0.08, alpha: 1.0)
        cacheColours[IFSyntaxStyle.directive.index] = NSColor(deviceRed: 3*0.20, green: 3*0.08, blue: 0.53, alpha: 1.0)
        cacheColours[IFSyntaxStyle.property.index] = NSColor(deviceRed: 3*0.08, green: 3*0.08, blue: 0.53, alpha: 1.0)
        cacheColours[IFSyntaxStyle.function.index] = NSColor(deviceRed: 3*0.08, green: 3*0.53, blue: 0.53, alpha: 1.0)
        cacheColours[IFSyntaxStyle.code.index] = NSColor(deviceRed: 0.46, green: 3*0.06, blue: 0.31, alpha: 1.0)
        cacheColours[IFSyntaxStyle.assembly.index] = NSColor(deviceRed: 0.46, green: 0.31, blue: 0.31, alpha: 1.0)
        cacheColours[IFSyntaxStyle.codeAlpha.index] = NSColor(deviceRed: 0.4, green: 0.4, blue: 0.3, alpha: 1.0)
        cacheColours[IFSyntaxStyle.escapeCharacter.index] = NSColor(deviceRed: 0.4, green: 0.4, blue: 0.3, alpha: 1.0)

        // Inform 7
        cacheColours[IFSyntaxStyle.title.index] = sourcePaper(for: .headings).colour
        cacheColours[IFSyntaxStyle.heading.index] = sourcePaper(for: .headings).colour
        cacheColours[IFSyntaxStyle.naturalInform.index] = sourcePaper(for: .mainText).colour
        cacheColours[IFSyntaxStyle.comment.index] = sourcePaper(for: .comments).colour
        cacheColours[IFSyntaxStyle.gameText.index] = sourcePaper(for: .quotedText).colour
        cacheColours[IFSyntaxStyle.substitution.index] = sourcePaper(for: .textSubstitutions).colour

        //
        // Set underscore for each style
        //
        // Inform 7
        cacheUnderlines[IFSyntaxStyle.title.index] = sourceUnderline(for: .headings)
        cacheUnderlines[IFSyntaxStyle.heading.index] = sourceUnderline(for: .headings)
        cacheUnderlines[IFSyntaxStyle.naturalInform.index] = sourceUnderline(for: .mainText)
        cacheUnderlines[IFSyntaxStyle.comment.index] = sourceUnderline(for: .comments)
        cacheUnderlines[IFSyntaxStyle.gameText.index] = sourceUnderline(for: .quotedText)
        cacheUnderlines[IFSyntaxStyle.substitution.index] = sourceUnderline(for: .textSubstitutions)

        // Finally... build the actual set of styles
        _styles = []

        let underline = NSNumber(value: NSUnderlineStyle.single.rawValue)
        let noUnderline = NSNumber(value: NSUnderlineStyle().rawValue)
        var currentUnderline: NSNumber

        for x in 0..<256 {
            if cacheUnderlines[x] {
                currentUnderline = underline
            }
            else {
                currentUnderline = noUnderline
            }

            let dict = NSMutableDictionary()

            if enableSyntaxColouring {
                dict[NSAttributedString.Key.foregroundColor] = cacheColours[x]
            }
            if enableSyntaxHighlighting {
                dict[NSAttributedString.Key.font] = cacheFontStyles[x]
                dict[NSAttributedString.Key.underlineStyle] = currentUnderline
            }

            _styles.append(dict)
        }
    }

    var styles: [NSMutableDictionary] {
        return _styles
    }

    // MARK: - Author's name

    private final func longUserName() -> String {
        var longuserName = NSFullUserName()
        if longuserName.isEmpty { longuserName = NSUserName() }
        if longuserName.isEmpty { longuserName = "Unknown Author" }

        return longuserName
    }

    var freshGameAuthorName: String! {
        get {
            var value = getPreferenceString("newGameAuthorName", default: "")

            value = (value as NSString).trimmingCharacters(in: .whitespaces)

            if value.isEmpty {
                // Use the current OS X user name
                return longUserName()
            } else {
                // Use the specified value
                return value
            }
        }
        set {
            var value = newValue
            if let name = value,
               ((name as NSString).lowercased as NSString).isEqual(to: (longUserName() as NSString).lowercased) {
                // Special case: if the user enters their own username, we go back to tracking that
                value = ""
            }

            setPreferenceString("newGameAuthorName", value: value, notification: .IFPreferencesAuthorDidChange)
        }
    }

    // MARK: - Advanced preferences

    var runBuildSh: Bool {
        get {
            return getPreferenceBool("runBuildSh", default: false)
        }
        set {
            setPreferenceBool("runBuildSh", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var alwaysCompile: Bool {
        get {
            return getPreferenceBool("alwaysCompile", default: false)
        }
        set {
            setPreferenceBool("alwaysCompile", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var showDebuggingLogs: Bool {
        get {
            return getPreferenceBool("showDebuggingLogs", default: false)
        }
        set {
            setPreferenceBool("showDebuggingLogs", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var showConsoleDuringBuilds: Bool {
        get {
            return getPreferenceBool("showConsoleDuringBuilds", default: false)
        }
        set {
            setPreferenceBool("showConsoleDuringBuilds", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var publicLibraryDebug: Bool {
        get {
            return getPreferenceBool("publicLibraryDebug", default: false)
        }
        set {
            setPreferenceBool("publicLibraryDebug", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var cleanProjectOnClose: Bool {
        get {
            return getPreferenceBool("cleanProjectOnClose", default: true)
        }
        set {
            setPreferenceBool("cleanProjectOnClose", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var alsoCleanIndexFiles: Bool {
        get {
            return getPreferenceBool("alsoCleanIndexFiles", default: false)
        }
        set {
            setPreferenceBool("alsoCleanIndexFiles", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var glulxInterpreter: String {
        get {
            if let value = preferences["glulxInterpreter"] as? String {
                return value
            } else {
                // Work out the default client to use
                var clientName: String? = "glulxe"
                if let configSettings = Bundle.main.infoDictionary?["InformConfiguration"] as? [String: Any] {
                    clientName = configSettings["GlulxInterpreter"] as? String
                }
                return clientName ?? "glulxe"
            }
        }
        set {
            setPreferenceString("glulxInterpreter", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    // Position of preferences window
    var preferencesTopLeftPosition: NSPoint {
        get {
            let x = getPreferenceDouble("PreferencesWindowX", default: 50.0)
            let y = getPreferenceDouble("PreferencesWindowY", default: 50.0)
            return NSPoint(x: x, y: y)
        }
        set {
            setPreferenceDouble("PreferencesWindowX", value: newValue.x, notification: nil)
            setPreferenceDouble("PreferencesWindowY", value: newValue.y, notification: nil)
        }
    }

    // External Inform Core directory
    var useExternalInformCoreDirectory: Bool {
        get {
            return getPreferenceBool("useExternalInformCoreDirectory", default: false)
        }
        set {
            setPreferenceBool("useExternalInformCoreDirectory", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }

    var externalInformCoreDirectory: String {
        get {
            return getPreferenceString("externalInformCoreDirectory", default: "")
        }
        set {
            setPreferenceString("externalInformCoreDirectory", value: newValue, notification: .IFPreferencesAdvancedDidChange)
        }
    }
}
