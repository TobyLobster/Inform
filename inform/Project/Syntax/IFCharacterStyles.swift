//
//  IFCharacterStyles.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFCharacterStyles.h.
//

import Foundation

@objc @implementation extension IFCharacterStyles {

    /// Syntax state for each character, in memory these styles own
    private final let charStyles: IFSyntaxStyles

    override init() {
        charStyles = IFSyntaxStyles()

        super.init()
    }

    deinit {
        if charStyles.styles != nil {
            free(charStyles.styles)
            charStyles.styles = nil
            charStyles.numCharStyles = 0
        }
    }

    var count: Int {
        return Int(charStyles.numCharStyles)
    }

    @objc(styleAtIndex:)
    func style(at index: Int) -> IFSyntaxStyle {
        return charStyles.read(index)
    }

    @objc(setStyle:atIndex:)
    func setStyle(_ style: IFSyntaxStyle, at index: Int) {
        charStyles.write(index, value: style)
    }

    //
    // What's the range of the current style at the given character index?
    //
    @objc(rangeOfStyleAtIndex:)
    func rangeOfStyle(at index: Int) -> NSRange {
        let style = charStyles.read(index)

        var localRange = NSRange(location: index, length: 0)       // Optimisation suggested by Shark

        while localRange.location > 0 {
            if charStyles.read(localRange.location - 1) == style {
                localRange.location -= 1
            } else {
                break
            }
        }

        let strLen = count

        while localRange.location + localRange.length < strLen {
            if charStyles.read(localRange.location + localRange.length) == style {
                localRange.length += 1
            } else {
                break
            }
        }

        return localRange
    }

    //
    // Given an edit that has just occured to the text, update the character styles
    //
    @objc(replaceStylesAfterEditingRange:changeInLength:)
    func replaceStyles(afterEditingRange newRange: NSRange, changeInLength: Int) {
        let oldRange      = NSRange(location: newRange.location, length: newRange.length - changeInLength)
        let oldFullLength = count
        let newFullLength = oldFullLength + changeInLength

        // Update the character styles of everything beyond our change
        let charactersToCopy = oldFullLength - oldRange.location - oldRange.length
        if changeInLength > 0 {
            // Move characters down (i.e. towards the back of the string)
            charStyles.styles = realloc(charStyles.styles, newFullLength)?
                .bindMemory(to: IFSyntaxStyle.self, capacity: newFullLength)
            charStyles.numCharStyles = UInt(newFullLength)

            if let styles = charStyles.styles {
                memmove(styles + newRange.location + newRange.length,
                        styles + oldRange.location + oldRange.length,
                        MemoryLayout<IFSyntaxStyle>.size * charactersToCopy)
            }
        } else {
            // Move characters up (i.e. towards the front of the string)
            if let styles = charStyles.styles {
                memmove(styles + newRange.location + newRange.length,
                        styles + oldRange.location + oldRange.length,
                        MemoryLayout<IFSyntaxStyle>.size * charactersToCopy)
            }

            charStyles.styles = realloc(charStyles.styles, newFullLength)?
                .bindMemory(to: IFSyntaxStyle.self, capacity: newFullLength)
            charStyles.numCharStyles = UInt(newFullLength)
        }

        // Characters in the edited range no longer have valid states
        precondition((newRange.length == 0) ||
                     ((newRange.length + newRange.location - 1) < Int(charStyles.numCharStyles)), "index out of range")
        var x = 0
        while x < newRange.length {
            charStyles.write(x + newRange.location, value: .styleNotHighlighted)
            x += 1
        }
    }

    @objc(stylesFromIndex:)
    func styles(from index: Int) -> IFSyntaxStyles {
        let styles = IFSyntaxStyles()
        styles.styles = charStyles.styles.map { $0 + index }
        styles.numCharStyles = charStyles.numCharStyles - UInt(index)
        return styles
    }
}
