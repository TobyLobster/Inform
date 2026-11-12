//
//  IFLineStyles.swift
//  Inform
//
//  Moved out of IFSyntaxData in November 2026. The interface is IFLineStyles.h.
//

import Cocoa

@objc @implementation extension IFLineStyles {

    /// The text, where its lines start, and the highlighter, whose tab width the tab stops are for
    private final let textStorage: NSTextStorage
    private final let lineStarts: IFLineStarts
    private final let highlighter: IFSyntaxHighlighter?

    private final var lineStyles: [[NSAttributedString.Key: Any]]     // NSParagraphStyles for each line

    /// The paragraph style of each line, until elastic tabs give a table's lines their own
    private final var lineParagraphStyle: [NSAttributedString.Key: Any]?

    init(text: NSTextStorage, lineStarts: IFLineStarts, highlighter: IFSyntaxHighlighter?) {
        self.textStorage = text
        self.lineStarts = lineStarts
        self.highlighter = highlighter

        lineStyles = [[:]]
        lineParagraphStyle = nil

        super.init()
    }

    var count: Int {
        return lineStyles.count
    }

    @objc(styleOfLine:)
    func style(ofLine line: Int) -> [NSAttributedString.Key: Any] {
        return lineStyles[line]
    }

    func forgetStandardStyle() {
        lineParagraphStyle = nil
    }

    //
    // Helper method.
    // Which line of text does the character index occur on?
    //
    private final func lineForIndex(_ index: Int) -> Int {
        return lineStarts.line(forIndex: index)
    }

    // MARK: - Keeping the styles in step

    @objc(replaceLinesAfter:through:withLines:)
    func replaceLines(after firstLine: Int, through lastLine: Int, with nNewLines: Int) {
        // Number of lines that have been added or taken away
        let lineDifference = nNewLines - (lastLine - firstLine)

        if nNewLines < (lastLine - firstLine) {
            lineStyles.removeSubrange((firstLine + 1)..<(firstLine + 1 - lineDifference))
        } else {
            lineStyles.removeSubrange((firstLine + 1)..<(lastLine + 1))

            for _ in 0..<nNewLines {
                lineStyles.insert(paragraphStyle(), at: firstLine + 1)
            }
        }
    }

    @objc(resetLine:)
    func resetLine(_ line: Int) {
        // Reset this line's paragraph style to the default (non-elastic) one.
        //
        // lineStyles[] is the record of which paragraph style each line of the text is
        // supposed to carry. Every edited line starts from the default here; Phase Two
        // applies it to the text, and Phase Three replaces it with an elastic one for
        // lines that turn out to be part of a table. Lines that are not edited keep
        // whatever they already have, in both lineStyles[] and the text.
        let newStyle = paragraphStyle()
        while lineStyles.count <= line {
            lineStyles.append(newStyle)
        }
        lineStyles[line] = newStyle
    }

    ///
    /// Apply the paragraph style recorded in lineStyles[] for the given line to the text.
    ///
    private final func applyLineStyle(forLine line: Int) {
        let firstChar = lineStarts.start(ofLine: line)
        let lastChar  = (line + 1) < lineStarts.count ? lineStarts.start(ofLine: line + 1) : textStorage.length
        let lineRange = NSRange(location: firstChar, length: lastChar - firstChar)

        textStorage.addAttributes(lineStyles[line],
                                  range: lineRange)
        textStorage.fixFontAttribute(in: lineRange)
    }

    @objc(applyStylesFromLine:through:)
    func applyStyles(from firstLine: Int, through lastLine: Int) {
        for line in firstLine...lastLine {
            applyLineStyle(forLine: line)
        }
    }

    // MARK: - Elastic tabs

    @objc(layOutTablesNearLinesFrom:through:updatingAll:changedRange:)
    func layOutTables(nearLinesFrom firstLine: Int,
                      through lastLine: Int,
                      updatingAll forceUpdateTabs: Bool,
                      changedRange: NSRange) -> NSRange {
        var changedRange = changedRange
        // The previous range formatted with elastic tabs
        var previousElasticRange = NSRange(location: NSNotFound, length: 0)

        // The tables in the text
        let tables = IFElasticTabs(string: textStorage.string)

        // Look one line either side of the edited lines as well. An edit can change the
        // layout of a table that it is not (or is no longer) part of: deleting a table's
        // last row, removing the tab from a row so that it leaves the table, or splitting
        // a table in two. Checking an extra line is cheap when it is not in a table, and
        // the comparison against lineStyles[] below skips any row whose stops are unchanged.
        let firstTabLine = (firstLine > 0) ? firstLine - 1 : firstLine
        let lastTabLine  = (lastLine + 1 < lineStarts.count) ? lastLine + 1 : lastLine
        var line = firstTabLine
        while line <= lastTabLine {
            // The range of characters on the line
            let firstChar = lineStarts.start(ofLine: line)

            // Get the region affected by these elastic tabs
            let elasticRange = tables.rangeOfRegion(at: UInt(firstChar))

            // If this was not the same as the region just handled...
            if elasticRange.location != NSNotFound &&
                elasticRange.location != previousElasticRange.location {
                // This is now the last elastic range (prevents us from formatting the same region twice)
                previousElasticRange = elasticRange

                // Lay out the tabs properly
                let newTabStops = elasticTabs(inRegion: elasticRange, of: tables)

                // Update the tabs over this region if necessary
                let firstElasticLine    = lineForIndex(elasticRange.location)
                var lastElasticLine     = lineForIndex(elasticRange.location + elasticRange.length)
                if elasticRange.location + elasticRange.length >= textStorage.length {
                    lastElasticLine += 1
                }
                while lastElasticLine >= lineStyles.count {
                    // Create a default line style for all unstyled lines,
                    // in case stage 1 didn't get here (for example, if this
                    // table runs past the edited region)
                    lineStyles.append(paragraphStyle())
                }
                for formatLine in stride(from: firstElasticLine, to: lastElasticLine, by: 1) {
                    // Skip lines that already carry these tab stops. lineStyles[] is
                    // reliable here: Phase One reset every edited line to the default
                    // style and Phase Two applied exactly that to the text, so a line
                    // whose recorded stops match the new ones really does have them.
                    // Edited lines never match (they hold the default), and if a
                    // column width changed then no line in the region matches, so
                    // the whole table is re-laid-out, as it must be.
                    if !forceUpdateTabs {
                        let currentPara = lineStyles[formatLine][.paragraphStyle] as? NSParagraphStyle
                        let currentTabs = currentPara?.tabStops ?? []
                        if newTabStops.count == currentTabs.count {
                            var tabsIdentical = true
                            for i in 0..<newTabStops.count {
                                if newTabStops[i].location != currentTabs[i].location {
                                    tabsIdentical = false
                                    break
                                }
                            }
                            if tabsIdentical {
                                continue
                            }
                        }
                    }

                    // Copy the styles for this line
                    var style = lineStyles[formatLine]
                    let paraStyle: NSMutableParagraphStyle
                    if let currentPara = style[.paragraphStyle] as? NSParagraphStyle {
                        paraStyle = currentPara.mutableCopy() as! NSMutableParagraphStyle
                    } else {
                        paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                    }

                    // Update the paragraph style with the new tabstops
                    paraStyle.tabStops = newTabStops
                    style[.paragraphStyle] = paraStyle

                    // Replace the line style, and apply it to the text
                    lineStyles[formatLine] = style
                    applyLineStyle(forLine: formatLine)
                }

                // Record that we have changed this range of attributes
                changedRange = NSUnionRange(changedRange, elasticRange)

                // Advance the enclosing loop to skip the lines we just laid out
                if line < lastElasticLine {
                    line = lastElasticLine - 1
                }
            }

            line += 1
        }

        return changedRange
    }

    // MARK: - Tabbing

    private final func generateParagraphStyle() -> [NSAttributedString.Key: Any] {
        let res = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle

        // Set the standard tabs, at the current width
        res.tabStops = IFTabStops.standardTabStops(forTabWidth: highlighter?.tabStopWidth ?? 0)

        return [.paragraphStyle: res]
    }

    /// The paragraph style of a line, with the standard tab stops. (Each number of tabs at the start of a line had a
    /// style of its own, to indent the line's wrapped text past them, until 515e4ae0 stopped indenting it.)
    private final func paragraphStyle() -> [NSAttributedString.Key: Any] {
        // Use the cached version if available
        if let lineParagraphStyle {
            return lineParagraphStyle
        }

        let style = generateParagraphStyle()
        lineParagraphStyle = style
        return style
    }

    // Given a character range, calculate the positions the 'elastic' tab stops should go at
    private final func elasticTabs(inRegion region: NSRange, of tables: IFElasticTabs) -> [NSTextTab] {
        // Now, chop up into lines and columns. Columns are separated by tabs. The last of the
        // lines is the current line.
        let lines = tables.cells(inRegion: region).map { line in
            line.map { textStorage.attributedSubstring(from: $0.rangeValue) }
        }
        return IFTabStops.elasticTabStops(forCells: lines, tabWidth: highlighter?.tabStopWidth ?? 0)
    }
}
