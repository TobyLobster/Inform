//
//  IFColourTheme.swift
//  Inform
//
//  Created by Toby Nelson in 2022
//  Translated from Objective-C in November 2026. The interface is still IFColourTheme.h.
//

import Cocoa

@objc @implementation extension IFColourTheme {

    var flags: NSNumber?
    var themeName: String?
    @NSCopying var sourcePaper: IFSyntaxColouringOption?
    @NSCopying var extensionPaper: IFSyntaxColouringOption?

    var options: [IFSyntaxColouringOption]

    override init() {
        var options: [IFSyntaxColouringOption] = []
        flags = 0

        options.insert(IFSyntaxColouringOption(), at: Int(IFSyntaxHighlightingOptionType.headings.rawValue))
        options.insert(IFSyntaxColouringOption(), at: Int(IFSyntaxHighlightingOptionType.mainText.rawValue))
        options.insert(IFSyntaxColouringOption(), at: Int(IFSyntaxHighlightingOptionType.comments.rawValue))
        options.insert(IFSyntaxColouringOption(), at: Int(IFSyntaxHighlightingOptionType.quotedText.rawValue))
        options.insert(IFSyntaxColouringOption(), at: Int(IFSyntaxHighlightingOptionType.textSubstitutions.rawValue))
        self.options = options
        super.init()

        resetSettings()
    }

    @objc(encodeWithCoder:)
    func encode(with encoder: NSCoder) {
        precondition(themeName != nil)
        precondition(flags != nil)
        precondition(sourcePaper != nil)
        precondition(extensionPaper != nil)

        encoder.encode(themeName,           forKey: "themeName")
        encoder.encode(flags,               forKey: "flags")
        encoder.encode(sourcePaper,         forKey: "sourcePaper")
        encoder.encode(extensionPaper,      forKey: "extensionPaper")
        encoder.encodeCInt(Int32(options.count), forKey: "optionsCount")
        for i in 0..<options.count {
            encoder.encode(options[i], forKey: "option\(i)")
        }
    }

    public required convenience init?(coder decoder: NSCoder) {
        self.init() // Call the designated initialiser first

        themeName           = decoder.decodeObject(of: NSString.self, forKey: "themeName") as String?
        flags               = decoder.decodeObject(of: NSNumber.self, forKey: "flags")
        sourcePaper         = decoder.decodeObject(of: IFSyntaxColouringOption.self, forKey: "sourcePaper")
        extensionPaper      = decoder.decodeObject(of: IFSyntaxColouringOption.self, forKey: "extensionPaper")

        var options: [IFSyntaxColouringOption] = []
        let optionsCount = decoder.decodeCInt(forKey: "optionsCount")
        for i in stride(from: 0, to: optionsCount, by: 1) {
            guard let option = decoder.decodeObject(of: IFSyntaxColouringOption.self, forKey: "option\(i)") else {
                // A damaged option: read the theme with no options, so that it can be left out
                options.removeAll()
                break
            }
            options.append(option)
        }
        self.options        = options
    }

    class var supportsSecureCoding: Bool {
        return true
    }

    func resetSettings() {
        if let sourcePaper {
            sourcePaper.colour = sourcePaper.defaultColour.copy() as! NSColor
        }
        if let extensionPaper {
            extensionPaper.colour = extensionPaper.defaultColour.copy() as! NSColor
        }

        for option in options {
            option.colour = option.defaultColour.copy() as! NSColor
        }
    }

    func createDuplicateSet() -> IFColourTheme {
        let result = IFColourTheme()

        result.themeName = themeName
        result.extensionPaper = extensionPaper?.copy() as? IFSyntaxColouringOption
        result.sourcePaper = sourcePaper?.copy() as? IFSyntaxColouringOption
        result.flags = flags?.copy() as? NSNumber

        result.options = options.map { $0.copy() as! IFSyntaxColouringOption }
        return result
    }

    func updateAppPreferencesFromSet(withEnable enable: Bool) {
        let prefs = IFPreferences.shared

        prefs.sourcePaper = sourcePaper!
        prefs.extensionPaper = extensionPaper!
        prefs.enableSyntaxColouring = enable

        for optionIndex in IFSyntaxHighlightingOptionType.headings.rawValue..<IFSyntaxHighlightingOptionType.count.rawValue {
            let option = options[Int(optionIndex)]
            prefs.setSourceColour(option.colour, for: IFSyntaxHighlightingOptionType(rawValue: optionIndex)!)
        }
    }

    func updateSetFromAppPreferences() {
        let prefs = IFPreferences.shared

        sourcePaper    = (prefs.sourcePaper.copy() as! IFSyntaxColouringOption)
        extensionPaper = (prefs.extensionPaper.copy() as! IFSyntaxColouringOption)
        flags          = prefs.getCurrentTheme().flags?.copy() as? NSNumber

        for optionIndex in IFSyntaxHighlightingOptionType.headings.rawValue..<IFSyntaxHighlightingOptionType.count.rawValue {
            let destOption = options[Int(optionIndex)]
            let prefsOption = prefs.sourcePaper(for: IFSyntaxHighlightingOptionType(rawValue: optionIndex)!)
            destOption.colour        = prefsOption.colour.copy() as! NSColor
            destOption.defaultColour = prefsOption.defaultColour.copy() as! NSColor
        }
    }

    @objc(optionOfType:)
    func option(of type: IFSyntaxHighlightingOptionType) -> IFSyntaxColouringOption {
        return options[Int(type.rawValue)]
    }

    private final func isEqualToColor(_ color1: NSColor?, with color2: NSColor?) -> Bool {
        guard let rgb1 = color1?.usingColorSpace(NSColorSpace.genericRGB),
              let rgb2 = color2?.usingColorSpace(NSColorSpace.genericRGB) else {
            return false
        }
        return rgb1.isEqual(rgb2)
    }

    @objc(equalToDefault)
    var isEqualToDefault: Bool {
        @objc(isEqualToDefault) get {
            if !isEqualToColor(sourcePaper?.colour, with: sourcePaper?.defaultColour) {
                return false
            }
            if !isEqualToColor(extensionPaper?.colour, with: extensionPaper?.defaultColour) {
                return false
            }
            for optionIndex in IFSyntaxHighlightingOptionType.headings.rawValue..<IFSyntaxHighlightingOptionType.count.rawValue {
                let option = options[Int(optionIndex)]

                if !isEqualToColor(option.colour, with: option.defaultColour) {
                    return false
                }
            }
            return true
        }
    }
}
