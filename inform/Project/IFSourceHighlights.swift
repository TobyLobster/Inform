//
//  IFSourceHighlights.swift
//  Inform
//
//  Moved out of IFProjectController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFSourceHighlights.h.
//

import Foundation

@objc @implementation extension IFSourceHighlights {
    // Source highlighting (indexed by file)
    private final var lineHighlighting: [String: [[NSNumber]]] = [:]
    private final var temporaryHighlights = false

    var files: [String] {
        return Array(lineHighlighting.keys)
    }

    var hasTemporaryHighlights: Bool {
        return temporaryHighlights
    }

    func highlights(inFile file: String?) -> [[NSNumber]]? {
        guard let file else { return nil }
        return lineHighlighting[file]
    }

    func highlightLine(_ line: Int, inFile file: String, style: IFLineStyle) {
        // Create a new line highlight for this file
        lineHighlighting[file, default: []].append([NSNumber(value: line),
                                                    NSNumber(value: style.rawValue)])

        if style.rawValue >= IFLineStyle._Temporary.rawValue && style.rawValue < IFLineStyle._LastTemporary.rawValue {
            temporaryHighlights = true
        }
    }

    @objc(removeHighlightsOfStyle:inFile:)
    func removeHighlights(of style: IFLineStyle, inFile file: String?) -> Bool {
        guard let file, let lineHighlight = lineHighlighting[file] else { return false }

        // Remove any highlights of this style
        let remaining = lineHighlight.filter { $0[1].uint32Value != style.rawValue }
        lineHighlighting[file] = remaining

        return remaining.count != lineHighlight.count
    }

    func temporaryHighlightsWereRemoved() {
        temporaryHighlights = false
    }
}
