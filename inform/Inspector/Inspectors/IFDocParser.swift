//
//  IFDocParser.swift
//  Inform
//
//  Created by Andrew Hunter on 28/10/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFDocParser.h.
//

import Cocoa

/// The UTF-16 code of an ASCII character
private func ascii(_ character: Unicode.Scalar) -> unichar {
    return unichar(UInt8(ascii: character))
}

/// The characters from `start` up to `end`, as a string (`characters` mustn't be empty, though the range may be)
private func string(_ characters: [unichar], from start: Int, to end: Int) -> NSString {
    return characters.withUnsafeBufferPointer { buffer in
        NSString(characters: buffer.baseAddress! + start, length: end - start)
    }
}

// = Information about a find within an example
@objc @implementation
extension IFExampleInfo {
    let name: String
    let anchorTag: String
    let range: NSRange

    init(name aName: String, anchorTag aAnchorTag: String, range aRange: NSRange) {
        name      = aName
        anchorTag = aAnchorTag
        range     = aRange

        super.init()
    }
}

@objc @implementation
extension IFCodeInfo {
    let anchorTag: String
    let range: NSRange

    init(anchorTag aAnchorTag: String, range aRange: NSRange) {
        anchorTag = aAnchorTag
        range     = aRange

        super.init()
    }
}

// MARK: - Static dictionaries

/// The tags whose contents aren't part of the text
private let ignoreTags: Set<String> = ["head", "script"]

/// The tags inside a line of text, which don't separate the text either side of them, as other tags do. (The
/// documentation's code has had a span round each word and mark since 2024.)
private let inlineTags: Set<String> = ["a", "abbr", "b", "big", "cite", "code", "em", "font", "i", "kbd", "q", "s",
                                       "samp", "small", "span", "strike", "strong", "sub", "sup", "tt", "u", "var"]

private let entities: [String: String] = [
    "lt": "<",
    "gt": ">",
    "quot": "\"",
    "amp": "&",
    "nbsp": " ",
]

private enum ParseState {
    case plainText
    case htmlTagOrComment
    case htmlTag
    case htmlCloseTag
    case htmlCommentStart1
    case htmlCommentStart2
    case htmlComment
    case htmlCommentEnd1
    case htmlCommentEnd2
    case htmlEntity
}

@objc @implementation
extension IFDocParser {

    // MARK: - The results

    let plainText: String
    let attributes: [IFDocAttributeKey: Any]
    let exampleInfo: [String: IFExampleInfo]
    let codeInfo: [IFCodeInfo]
    let definitionInfo: [IFCodeInfo]

    // MARK: - Initialisation

    /// The value of an entity (without its & and ;): one of the named ones above, or a character given by its
    /// number, such as #160 or #x2318 (nil if it's neither)
    private static func valueOfEntity(_ entity: String) -> String? {
        var value = entities[entity]
        if value == nil && entity.hasPrefix("#") {
            let hex = entity.hasPrefix("#x")
            let scanner = Scanner(string: (entity as NSString).substring(from: hex ? 2 : 1))
            let code = scanner.scanUInt64(representation: hex ? .hexadecimal : .decimal)
            if let code, scanner.isAtEnd, code > 0, code <= 0x10FFFF, code < 0xD800 || code > 0xDFFF {
                if code == 0xA0 {
                    // A non-breaking space is a space, as &nbsp; is
                    value = " "
                } else {
                    value = String(Character(Unicode.Scalar(UInt32(code))!))
                }
            }
        }
        return value
    }

    /// The quoted text of a marker comment, after the prefix that ends with its opening quote and without its
    /// closing quote (nil if the comment is too short to have them)
    private static func textOfMarker(_ comment: NSString, afterPrefix prefixLength: Int) -> String? {
        if comment.length < prefixLength + 1 {
            return nil
        }
        return comment.substring(with: NSRange(location: prefixLength, length: comment.length - (prefixLength + 1)))
    }

    init(html: String) {
        // Prepare the results string
        var attr: [IFDocAttributeKey: Any] = [:]
        var exInfo: [String: IFExampleInfo] = [:]
        var cdInfo: [IFCodeInfo] = []
        var dfInfo: [IFCodeInfo] = []

        // Parse the HTML
        let source = html as NSString
        let len = source.length
        var chrs = [unichar](repeating: 0, count: len)
        source.getCharacters(&chrs, range: NSRange(location: 0, length: len))
        var result: [unichar] = []
        result.reserveCapacity(len)

        var state = ParseState.plainText
        var whitespace = true
        var inTitle = false
        var exampleName = ""
        var exampleAnchorTag = ""
        var exampleStartLocation = 0
        var codeStartLocation = 0
        var codeAnchorTag = ""
        var definitionStartLocation = 0
        var definitionAnchorTag = ""
        var ignoreSection = false

        var title: [unichar] = []

        var tagStart = 0
        var ignoreCount = 0

        /// Adds a single character of whitespace to separate the text either side of a tag or comment
        func separateText() {
            if ignoreCount == 0 && !ignoreSection && !whitespace {
                whitespace = true
                result.append(ascii(" "))
            }
        }

        for x in 0..<len {
            switch state {
            case .plainText:
                // This is a plain text section
                switch chrs[x] {
                case ascii(" "), ascii("\t"), ascii("\n"), ascii("\r"):
                    // This is whitespace: append a maximum of one item of whitespace at a time
                    if inTitle && !whitespace {
                        whitespace = true
                        title.append(ascii(" "))
                    }
                    if ignoreCount != 0 { break }
                    if ignoreSection { break }

                    if !whitespace {
                        whitespace = true
                        result.append(ascii(" "))
                    }

                case ascii("<"):
                    // This is the beginning of a comment or a tag, which separates the text unless it's an inline
                    // tag: that's known where it ends
                    state = .htmlTagOrComment
                    tagStart = x

                case ascii("&"):
                    // This is the beginning of an entity
                    state = .htmlEntity
                    tagStart = x

                default:
                    // This is a non-whitespace character
                    if inTitle {
                        whitespace = false
                        title.append(chrs[x])
                    }
                    if ignoreCount != 0 { break }
                    if ignoreSection { break }

                    whitespace = false
                    result.append(chrs[x])
                }

            case .htmlEntity:
                switch chrs[x] {
                case ascii(" "), ascii("\t"), ascii("\n"), ascii("\r"), ascii(";"):
                    let entity = string(chrs, from: tagStart + 1, to: x).lowercased
                    let entityValue = IFDocParser.valueOfEntity(entity)

                    // End of this entity
                    state = .plainText
                    if inTitle {
                        whitespace = false
                        if let entityValue {
                            title.append(contentsOf: entityValue.utf16)
                        }
                    }
                    if ignoreCount != 0 { break }
                    if ignoreSection { break }

                    whitespace = false
                    if let entityValue {
                        result.append(contentsOf: entityValue.utf16)
                    }

                default:
                    // The entity continues
                    break
                }

            case .htmlTagOrComment:
                // This is either the beginning of a tag, or the beginning of a comment, or the beginning of a close tag
                switch chrs[x] {
                case ascii("/"):
                    state = .htmlCloseTag
                    tagStart = x

                case ascii("!"):
                    state = .htmlCommentStart1

                case ascii(">"):
                    separateText()
                    state = .plainText

                default:
                    state = .htmlTag
                }

            case .htmlTag, .htmlCloseTag:
                switch chrs[x] {
                case ascii(">"):
                    // End of this tag

                    // Get the tag
                    var tag = string(chrs, from: tagStart + 1, to: x)
                    let spaceLoc = tag.range(of: " ").location
                    if spaceLoc != NSNotFound { tag = tag.substring(to: spaceLoc) as NSString }

                    let tagName = tag.lowercased

                    if !inlineTags.contains(tagName) {
                        separateText()
                    }

                    // If this is an ignore tag, then increase/decrease the ignore count
                    if ignoreTags.contains(tagName) {
                        if state == .htmlTag {
                            ignoreCount += 1
                        } else {
                            ignoreCount -= 1
                        }
                    }

                    if ignoreCount <= 0 && (tagName == "br" || tagName == "p") {
                        if !ignoreSection {
                            whitespace = true
                            result.append(ascii("\n"))
                        }
                    }

                    if tagName == "title" {
                        if state == .htmlTag {
                            inTitle = true
                            whitespace = true
                        } else {
                            inTitle = false
                            whitespace = true
                        }
                    }

                    state = .plainText

                default:
                    // The tag continues
                    break
                }

            case .htmlCommentStart1:
                switch chrs[x] {
                case ascii("-"):
                    state = .htmlCommentStart2

                default:
                    state = .htmlTag
                }

            case .htmlCommentStart2:
                switch chrs[x] {
                case ascii("-"):
                    state = .htmlComment

                default:
                    state = .htmlTag
                }

            case .htmlComment:
                switch chrs[x] {
                case ascii("-"):
                    state = .htmlCommentEnd1

                default:
                    // The comment continues
                    break
                }

            case .htmlCommentEnd1:
                switch chrs[x] {
                case ascii("-"):
                    // '--' has been matched if we get here
                    state = .htmlCommentEnd2

                default:
                    // The comment continues
                    state = .htmlComment
                }

            case .htmlCommentEnd2:
                switch chrs[x] {
                case ascii(">"):
                    // End of this comment
                    state = .plainText
                    separateText()

                    var comment = string(chrs, from: tagStart, to: x)

                    // Strip down this comment
                    comment = comment.substring(from: 4) as NSString                     // Removes <!--
                    comment = comment.substring(to: comment.length - 2) as NSString      // Removes --
                    // Removes the spaces inside, which the documentation has had since 2024
                    comment = comment.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

                    // Look for interesting comments
                    if comment.hasPrefix("START EXAMPLE \"") {
                        let prefixLen = "START EXAMPLE \"".utf16.count
                        // Remember the name, anchor id and location of the Example
                        if let postfix = IFDocParser.textOfMarker(comment, afterPrefix: prefixLen) {
                            let array = postfix.components(separatedBy: "\" \"")

                            if array.count == 2 {
                                exampleName = array[0]
                                exampleAnchorTag = array[1]
                                exampleStartLocation = result.count
                            }
                        }
                    } else if comment.hasPrefix("END EXAMPLE") {
                        let exampleEndLocation = result.count
                        // Record the range for this example
                        if exInfo[exampleName] == nil {
                            let range = NSRange(location: exampleStartLocation, length: exampleEndLocation - exampleStartLocation)
                            let info = IFExampleInfo(name: exampleName,
                                                     anchorTag: exampleAnchorTag,
                                                     range: range)
                            exInfo[exampleName] = info
                        }
                    } else if comment.hasPrefix("START CODE") {
                        let prefixLen = "START CODE \"".utf16.count
                        // Remember the anchor id
                        if let postfix = IFDocParser.textOfMarker(comment, afterPrefix: prefixLen) {
                            let array = postfix.components(separatedBy: "\" \"")

                            if array.count == 1 {
                                codeAnchorTag = array[0]
                                codeStartLocation = result.count
                            }
                        }
                    } else if comment.hasPrefix("END CODE") {
                        let codeEndLocation = result.count
                        // Record the range for this code
                        let range = NSRange(location: codeStartLocation, length: codeEndLocation - codeStartLocation)
                        let info = IFCodeInfo(anchorTag: codeAnchorTag,
                                              range: range)
                        cdInfo.append(info)
                    } else if comment.hasPrefix("START PHRASE") {
                        let prefixLen = "START PHRASE \"".utf16.count
                        // Remember the anchor id
                        if let postfix = IFDocParser.textOfMarker(comment, afterPrefix: prefixLen) {
                            let array = postfix.components(separatedBy: "\" \"")

                            if array.count == 1 {
                                definitionAnchorTag = array[0]
                                definitionStartLocation = result.count
                            }
                        }
                    } else if comment.hasPrefix("END PHRASE") {
                        let definitionEndLocation = result.count
                        // Record the range for this code
                        let range = NSRange(location: definitionStartLocation, length: definitionEndLocation - definitionStartLocation)
                        let info = IFCodeInfo(anchorTag: definitionAnchorTag,
                                              range: range)
                        dfInfo.append(info)
                    } else if comment.hasPrefix("START IGNORE") {
                        ignoreSection = true
                    } else if comment.hasPrefix("END IGNORE") {
                        ignoreSection = false
                    } else if comment.hasPrefix("SEARCH TITLE \"") {
                        let prefixLen = "SEARCH TITLE \"".utf16.count
                        if let text = IFDocParser.textOfMarker(comment, afterPrefix: prefixLen) {
                            attr[.title] = text
                        }
                    } else if comment.hasPrefix("SEARCH SECTION \"") {
                        let prefixLen = "SEARCH SECTION \"".utf16.count
                        if let text = IFDocParser.textOfMarker(comment, afterPrefix: prefixLen) {
                            attr[.section] = text
                        }
                    } else if comment.hasPrefix("SEARCH SORT \"") {
                        let prefixLen = "SEARCH SORT \"".utf16.count
                        if let text = IFDocParser.textOfMarker(comment, afterPrefix: prefixLen) {
                            attr[.sort] = text
                        }
                    }

                case ascii("-"):
                    // Comment might end later on
                    break

                default:
                    // The comment continues
                    state = .htmlComment
                }
            }
        }

        // Tidy up
        attr[.htmlTitle] = NSString(characters: title, length: title.count) as String

        plainText      = NSString(characters: result, length: result.count) as String
        exampleInfo    = exInfo
        codeInfo       = cdInfo
        definitionInfo = dfInfo
        attributes     = attr

        super.init()
    }
}
