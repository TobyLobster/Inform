//
//  IFIntelFile.swift
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFIntelFile.h, and
//  IFIntelFileHasChangedNotification is defined in IFIntelConstants.m.
//

import Cocoa

// To log the changes, add IntelDebug to the Active Compilation Conditions.

// FIXME: symbols are supposed to be deliniated by type, so we should really be using one of these objects
// per symbol type;

@objc @implementation extension IFIntelFile {

    // Data
    /// List of symbols added to the file
    private var symbols: [IFIntelSymbol]
    /// The line number each symbol in the symbols array occurs on (ie, one entry per symbol)
    private var symbolLines: [Int]

    // Notifications
    /// true if we're preparing to send a notification that this object has changed
    private var notificationPending: Bool

    override init() {
        symbols             = []
        symbolLines         = []
        notificationPending = false

        super.init()
    }

    private func indexOfSymbol(onLine lineNumber: Int) -> Int {
        // BINARY SEARCH POWER! Is there anything this wacky algorithm cannot do?

        // Either the last item of the previous line, or the first item of this line
        let nSymbols = symbols.count

        if nSymbols == 0 { return -1 }

        var bottom = 0
        var top = nSymbols - 1
        var middle = 0
        while top >= bottom {
            middle = (top + bottom) >> 1

            if symbolLines[middle] < lineNumber {
                bottom = middle + 1
            } else if symbolLines[middle] > lineNumber {
                top = middle - 1
            } else {
                return middle
            }
        }

        return middle
    }

    private func indexOfStartOfLine(_ lineNumber: Int) -> Int {
        // Returns the symbol location of the symbol before the start of the line
        var symbol = indexOfSymbol(onLine: lineNumber)

        while symbol >= 0 && symbolLines[symbol] >= lineNumber { symbol -= 1 }

        return symbol
    }

    private func indexOfEndOfLine(_ lineNumber: Int) -> Int {
        // Returns the symbol location of the symbol after the start of the line
        var symbol = indexOfSymbol(onLine: lineNumber)
        let nSymbols = symbols.count

        while symbol >= 0 && symbolLines[symbol] >= lineNumber { symbol -= 1 }
        if symbol < 0 { symbol = 0 }
        while symbol < nSymbols && symbolLines[symbol] <= lineNumber { symbol += 1 }

        return symbol
    }

    // MARK: - Adding and removing symbols

    func insertLine(beforeLine line: Int32) {
        // Renumber lines as appropriate
        let firstSymbol = indexOfStartOfLine(Int(line)) + 1
        let nSymbols = symbols.count

        #if IntelDebug
        NSLog("Intel: adding line before line %i (starting at symbol %ld)", line, firstSymbol)
        #endif

        for symbol in firstSymbol..<nSymbols {
            symbolLines[symbol] += 1
        }

        intelFileHasChanged()
    }

    func removeLines(_ lines: NSRange) {
        // Clear out the symbols for these lines
        clearSymbols(forLines: lines)

        // Change the location of the remaining lines
        let firstSymbol = indexOfStartOfLine(lines.location) + 1
        let nSymbols = symbols.count

        #if IntelDebug
        NSLog("Intel: removing %ld lines after line %ld (starting at symbol %ld)", lines.length, lines.location, firstSymbol)
        #endif

        for symbol in firstSymbol..<nSymbols {
            symbolLines[symbol] -= lines.length
        }

        intelFileHasChanged()
    }

    func clearSymbols(forLines lines: NSRange) {
        // These are EXCLUSIVE (remember?)
        let firstSymbol = indexOfStartOfLine(lines.location)
        let lastSymbol = indexOfStartOfLine(lines.location + lines.length) + 1

        if firstSymbol >= lastSymbol {
            // Should never happen (aka the Programmer's Lament)
            NSLog("BUG: clearSymbols for line symbol %ld > %ld", firstSymbol, lastSymbol)
            NSLog("[IFIntelFile clearSymbolsForLines] failed")
            return
        }

        // firstSymbol+1 == lastSymbol iff there are no symbols to remove
        if firstSymbol + 1 == lastSymbol {
            return
        }

        #if IntelDebug
        NSLog("Clearing symbols for lines (%ld-%ld). Symbol range (%ld-%ld)", lines.location, lines.location + lines.length, firstSymbol, lastSymbol)
        #endif

        // Remove symbols between firstSymbol and lastSymbol

        // First remove from the list
        var before: IFIntelSymbol? = nil
        if firstSymbol >= 0 { before = symbols[firstSymbol] }

        for x in (firstSymbol + 1)..<lastSymbol {
            let thisSymbol = symbols[x]

            #if IntelDebug
            NSLog("\tClearing symbol '%@' (line %ld)", thisSymbol, symbolLines[x])
            #endif

            thisSymbol.next = nil
            thisSymbol.last = nil
        }

        var after: IFIntelSymbol? = nil
        if lastSymbol < symbols.count { after = symbols[lastSymbol] }

        if let before { before.next = after }
        if let after { after.last = before }

        // Remove from the arrays
        symbols.removeSubrange((firstSymbol + 1)..<lastSymbol)
        symbolLines.removeSubrange((firstSymbol + 1)..<lastSymbol)

        intelFileHasChanged()
    }

    @objc(addSymbol:atLine:)
    func add(_ newSymbol: IFIntelSymbol,
             atLine line: Int32) {
        let symbol = indexOfEndOfLine(Int(line))
        let nSymbols = symbols.count

        #if IntelDebug
        NSLog("Inserting symbol %@ at line %i (symbol location %ld)", newSymbol, line, symbol)
        #endif

        // Need to insert at symbol...
        symbolLines.insert(Int(line), at: symbol)
        symbols.insert(newSymbol, at: symbol)

        // Adjust the symbol list
        if symbol > 0 {
            newSymbol.last = symbols[symbol - 1]
        } else {
            newSymbol.last = nil
        }

        if symbol < nSymbols {
            newSymbol.next = symbols[symbol + 1]
        } else {
            newSymbol.next = nil
        }

        newSymbol.last?.next = newSymbol
        newSymbol.next?.last = newSymbol

        intelFileHasChanged()
    }

    // MARK: - Debug

    public override var description: String {
        var res = "<IFIntelFile \(symbols.count) symbols:"

        for symbol in 0..<symbols.count {
            res += "\n\tLine \(symbolLines[symbol]) - \(symbols[symbol])"
        }

        res += ">"

        return res
    }

    // MARK: - Finding symbols

    func nearestSymbol(toLine line: Int32) -> IFIntelSymbol? {
        let line = Int(line)
        let nSymbols = symbols.count
        let symbol = indexOfStartOfLine(line)

        // Special case: for the very first symbol in the file, there is no 'preceding symbol', so we would otherwise abort here
        if nSymbols > 0 && symbol == -1 && symbolLines[0] == line { return symbols[0] }

        if symbol < 0 { return nil }
        if symbol >= nSymbols { return nil }
        if symbol + 1 == nSymbols { return symbols[symbol] }
        if symbolLines[symbol + 1] == line { return symbols[symbol + 1] }

        return symbols[symbol]
    }

    @objc(lineForSymbol:)
    func line(for symbolToFind: IFIntelSymbol?) -> UInt {
        for symbol in 0..<symbols.count {
            if symbols[symbol] === symbolToFind {
                return UInt(bitPattern: symbolLines[symbol])
            }
        }

        return UInt(NSNotFound)
    }

    var firstSymbol: IFIntelSymbol? {
        return symbols.first
    }

    func intelFileHasChanged() {
        if !notificationPending {
            notificationPending = true
            perform(#selector(finishNotifyingChange), with: self, afterDelay: 2.0)
        }
    }

    @objc private func finishNotifyingChange() {
        NotificationCenter.default.post(name: .IFIntelFileHasChanged, object: self)
        notificationPending = false
    }
}
