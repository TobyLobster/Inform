//
//  IFFindResult.swift
//  Inform
//
//  Created by Andrew Hunter on 17/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFFindResult.h.
//

import Cocoa

/// The UTF-16 code of an ASCII character
private func ascii(_ character: Unicode.Scalar) -> unichar {
    return unichar(UInt8(ascii: character))
}

@objc @implementation
extension IFFindResult {
    let filepath: String?
    let fileRange: NSRange
    let documentDisplayName: String?
    let documentSortName: String?
    let locationType: IFFindLocation
    let context: String
    let contextRange: NSRange
    let exampleName: String?
    let exampleAnchorTag: String?
    let codeAnchorTag: String?
    let definitionAnchorTag: String?
    let regexFoundGroups: [String]?

    private final var hasError = false

    // MARK: - Initialisation

    init(filepath aFilepath: String?,
         rangeInFile aFileRange: NSRange,
         documentDisplayName aDocumentDisplayName: String?,
         documentSortName aDocumentSortName: String?,
         locationType aLocationType: IFFindLocation,
         context aContext: String,
         contextRange aContextRange: NSRange,
         exampleName aExampleName: String?,
         exampleAnchorTag aExampleAnchorTag: String?,
         codeAnchorTag aCodeAnchorTag: String?,
         definitionAnchorTag aDefinitionAnchorTag: String?,
         regexFoundGroups aRegexFoundGroups: [String]?) {
        filepath            = aFilepath
        fileRange           = aFileRange
        documentDisplayName = aDocumentDisplayName
        documentSortName    = aDocumentSortName
        locationType        = aLocationType
        context             = aContext
        contextRange        = aContextRange
        exampleName         = aExampleName
        exampleAnchorTag    = aExampleAnchorTag
        codeAnchorTag       = aCodeAnchorTag
        definitionAnchorTag = aDefinitionAnchorTag
        regexFoundGroups    = aRegexFoundGroups

        super.init()
    }

    // MARK: - Data

    var phrase: String {
        return (context as NSString).substring(with: contextRange)
    }

    var recipeBookResult: Bool {
        // (The header names the getter, which Swift doesn't take from it)
        @objc(isRecipeBookResult)
        get {
            // sort name starts with 000 for Writing With Inform
            // sort name starts with 001 for The Inform Recipe Book
            return documentSortName?.hasPrefix("001") ?? false
        }
    }

    func setError(_ newHasError: Bool) {
        hasError = newHasError
    }

    class func string(byReplacingGroups replace: String,
                      regexFoundGroups aRegexFoundGroups: [String]?) -> String {
        //
        // In a regex replacement string, we want:
        //
        //      \0 through \9 to be replaced with the corresponding found group.
        //      \\ to \.
        //      \t \n \v \f \r to characters 9 to 13 (tab, newline, vertical tab, form feed, return).
        //      \x09 (etc) to utf8 code
        //
        let mutReplace = NSMutableString()
        mutReplace.setString(replace)

        var foundSlash = false
        var i = 0
        while i < mutReplace.length {
            var c = mutReplace.character(at: i)

            if c == ascii("\\") {
                if foundSlash {
                    // We have found '\\'. We Remove the second slash.
                    mutReplace.deleteCharacters(in: NSRange(location: i, length: 1))
                    i -= 1
                    foundSlash = false
                } else {
                    // We have found our first slash
                    foundSlash = true
                }
            } else if foundSlash {
                if (c >= ascii("0")) && (c <= ascii("9")) {
                    // We have found one of \0 to \9
                    let group = Int(c - ascii("0"))

                    if let aRegexFoundGroups, aRegexFoundGroups.count > group {
                        // Remove the \0
                        mutReplace.deleteCharacters(in: NSRange(location: i - 1, length: 1))
                        mutReplace.deleteCharacters(in: NSRange(location: i - 1, length: 1))

                        let groupString = aRegexFoundGroups[group]

                        // Insert the matched string
                        mutReplace.insert(groupString, at: i - 1)
                        i = (i - 1) + ((groupString as NSString).length - 1)
                    }
                }
                else if (c == ascii("t")) || (c == ascii("n")) || (c == ascii("v")) || (c == ascii("f")) || (c == ascii("r")) {
                    if c == ascii("t") { c = 9 }
                    else if c == ascii("n") { c = 10 }
                    else if c == ascii("v") { c = 11 }
                    else if c == ascii("f") { c = 12 }
                    else if c == ascii("r") { c = 13 }
                    let unicharString = String(format: "%C", c)
                    mutReplace.replaceCharacters(in: NSRange(location: i - 1, length: 2), with: unicharString)
                    i -= 1    // Carry on after the character we've inserted
                } else if c == ascii("x") {
                    let hexDigits = NSCharacterSet(charactersIn: "0123456789abcdefABCDEF")
                    if i < (mutReplace.length - 2)
                        && hexDigits.characterIsMember(mutReplace.character(at: i + 1))
                        && hexDigits.characterIsMember(mutReplace.character(at: i + 2)) {
                        let scanner = Scanner(string: mutReplace.substring(with: NSRange(location: i + 1, length: 2)))

                        let hexInt = scanner.scanUInt64(representation: .hexadecimal) ?? 0
                        let unicharString = String(format: "%C", unichar(hexInt))
                        mutReplace.replaceCharacters(in: NSRange(location: i - 1, length: 4), with: unicharString)
                        i -= 1    // Carry on after the character we've inserted
                    }
                }
                foundSlash = false
            }
            i += 1
        }
        return mutReplace as String
    }

    func string(byReplacingGroups replace: String) -> String {
        return IFFindResult.string(byReplacingGroups: replace, regexFoundGroups: regexFoundGroups)
    }

    var attributedContext: NSAttributedString {
        let style = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle

        let italicsAttributes: [NSAttributedString.Key: Any]
        let normalAttributes: [NSAttributedString.Key: Any]
        let boldAttributes: [NSAttributedString.Key: Any]
        if hasError {
            italicsAttributes = [.font: NSFont(name: "Helvetica", size: 11)!, // system font doesn't do italics, so we use Helvetica instead.
                                 .foregroundColor: NSColor.systemRed,
                                 .paragraphStyle: style]
            normalAttributes = [.font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.systemRed,
                                .paragraphStyle: style]
            boldAttributes = [.font: NSFont.systemFont(ofSize: 12),
                              .foregroundColor: NSColor.systemRed,
                              .paragraphStyle: style]
        } else {
            italicsAttributes = [.font: NSFont(name: "Helvetica", size: 11)!, // system font doesn't do italics, so we use Helvetica instead.
                                 .foregroundColor: NSColor.textColor,
                                 .paragraphStyle: style]
            normalAttributes = [.font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.textColor,
                                .paragraphStyle: style]
            boldAttributes = [.font: NSFont.systemFont(ofSize: 12),
                              .foregroundColor: NSColor.textColor,
                              .paragraphStyle: style]
        }

        let result = NSMutableAttributedString(string: context,
                                               attributes: normalAttributes)
        result.beginEditing()
        result.addAttributes(boldAttributes,
                             range: contextRange)
        result.applyFontTraits(.boldFontMask, range: contextRange)

        // Prefix with example, if there is one
        if let exampleName, !exampleName.isEmpty {
            var prefix = IFUtility.localizedString("SearchResultInExamplePrefix",
                                                   default: "(Example %@)  ")
            prefix = String(format: prefix, exampleName)
            let examplePrefix = NSAttributedString(string: prefix, attributes: italicsAttributes)
            result.insert(examplePrefix, at: 0)

            result.applyFontTraits(.italicFontMask,
                                   range: NSRange(location: 0, length: examplePrefix.length))
        }
        result.endEditing()

        return result
    }
}
