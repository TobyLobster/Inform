//
//  IFRuntimeErrorParser.swift
//  Inform
//
//  Created by Andrew Hunter on 10/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFRuntimeErrorParser.h.
//

import Foundation

@objc @implementation
extension IFRuntimeErrorParser {
    /// The character accumulator
    private final var accumulator: NSMutableString

    weak var delegate: IFRuntimeErrorParserDelegate?

    override init() {
        accumulator = NSMutableString()
        super.init()
    }

    func outputText(_ outputText: String) {
        // The story's output arrives in pieces of any size, so collect it into lines, and check
        // each line once it is complete
        accumulator.append(outputText)

        var newline = accumulator.range(of: "\n")
        while newline.location != NSNotFound {
            let line = accumulator.substring(to: newline.location)
            accumulator.deleteCharacters(in: NSRange(location: 0, length: NSMaxRange(newline)))
            checkLine(line)
            newline = accumulator.range(of: "\n")
        }
    }

    /// Tells the delegate if this line of the story's output announces a run-time problem
    private final func checkLine(_ line: String) {
        // Scan for '*** Run-time problem XX' at the beginning of a line: this indicates that runtime problem XX
        // has occured (and we should probably be showing file RTP_XX.html). A story compiled with
        // debugging follows it with ': ' and the folder holding the problem's explanation.

        var problemType: String? = nil
        var directory: String? = nil

        if let match = IFUtility.findMatch("^\\*\\*\\* Run-time problem\\s+([^\\s:]+)(?::\\s*(.*))?$", inText: line) {
            let type = (line as NSString).substring(with: match.range(at: 1))
            problemType = type
            let oldStyleMatches = IFUtility.findMatch("P\\d+", inText: type)
            if oldStyleMatches == nil && match.range(at: 2).location != NSNotFound {
                directory = (line as NSString).substring(with: match.range(at: 2))
            }
        }

        if let problemType {
            // A problem was encountered: inform the delegate
            delegate?.runtimeError?(problemType, inDirectory: directory)
        }
    }

    // Notifications about events that have occured in the view (when using this automation object for output)

    /// Text has arrived at the specified text buffer window (from the game)
    @objc(receivedCharacters:window:fromView:)
    func receivedCharacters(_ characters: String!,
                            window windowNumber: Int32,
                            from view: GlkView!) {
        outputText(characters)
    }

    /// The user has typed the specified string into the specified window (which is any window that is waiting for input)
    @objc(userTyped:window:lineInput:fromView:)
    func userTyped(_ userInput: String!,
                   window windowNumber: Int32,
                   lineInput isLineInput: Bool,
                   from view: GlkView!) {
    }

    /// The user has clicked at a specified position in the given window
    @objc(userClickedAtXPos:ypos:window:fromView:)
    func userClicked(atXPos xpos: Int32,
                     ypos: Int32,
                     window windowNumber: Int32,
                     from view: GlkView!) {
    }

    @objc(viewWaiting:)
    func viewWaiting(_ view: GlkView!) {

    }

    // Using this automation object for input

    @objc(viewIsWaitingForInput:)
    func viewIsWaiting(forInput view: GlkView!) {

    }
}
