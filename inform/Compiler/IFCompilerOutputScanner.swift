//
//  IFCompilerOutputScanner.swift
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//  Translated from Objective-C in November 2026, and the lexer it used, IFError.l, from flex. The interface is still
//  IFCompilerOutputScanner.h.
//

import Foundation

@objc @implementation extension IFCompilerOutputScanner {
    weak var delegate: IFCompilerOutputScannerDelegate?

    func style(forLine line: String) -> String? {
        let res = scan(line)

        switch res {
        case IFLexCompilerVersion:
            return IFStyleCompilerVersion

        case IFLexCompilerMessage:
            return IFStyleCompilerMessage

        case IFLexCompilerWarning:
            return IFStyleCompilerWarning

        case IFLexCompilerError:
            return IFStyleCompilerError

        case IFLexCompilerFatalError:
            return IFStyleCompilerFatalError

        case IFLexProgress:
            return IFStyleProgress

        case IFLexEndText:
            return IFStyleCompilerMessage

        default:
            break
        }

        return nil
    }

    // MARK: - Scanning

    /// Scans a line as the lexer in IFError.l did, for the kind of line it is, telling the delegate what it says.
    /// Like the lexer, it works with the line's bytes, and looks no further than its first newline.
    private final func scan(_ line: String) -> IFLex? {
        let bytes = Array(line.utf8)
        let newline = bytes.firstIndex(of: UInt8(ascii: "\n"))
        let text = bytes[..<(newline ?? bytes.endIndex)]

        // The compiler's version
        if text.hasPrefix("Inform 7") || text.hasPrefix("Inform 6") {
            return IFLexCompilerVersion
        }

        // Each of the other kinds of line ends with its newline
        guard newline != nil else {
            return nil
        }

        // Where cblorb asks for the blorb file to be copied: Copy blorb to: [[<location>]]
        if let location = text.between("Copy blorb to: [[", and: "]]") {
            delegate?.outputScanner(self, copyBlorbTo: String(decoding: location, as: UTF8.self))
            return IFLexCompilerMessage
        }

        // A progress line: ++ <percentage>%, or with the stage the compiler has reached, ++ <percentage>% (<stage>)
        if text.hasPrefix("++ ") {
            let digits = text.dropFirst(3).prefix(while: isDigit)
            let rest = text[digits.endIndex...]

            if !digits.isEmpty && rest.elementsEqual("%".utf8) {
                delegate?.outputScanner(self, hasProgress: number(digits), message: nil)
                return IFLexProgress
            }
            if !digits.isEmpty, let stage = rest.between("% (", and: ")") {
                delegate?.outputScanner(self,
                                        hasProgress: number(digits),
                                        message: String(decoding: stage, as: UTF8.self))
                return IFLexProgress
            }
        }

        // The line that says how the compiler ended: ++ Ended: <end text>
        if text.hasPrefix("++ Ended: ") {
            delegate?.outputScanner(self, hasEndText: String(decoding: text.dropFirst(10), as: UTF8.self))
            return IFLexEndText
        }

        // An error that Inform 6 gives for a line of a file, in the format the app asks for
        if let headerEnd = inform6HeaderEnd(text) {
            return scanInform6Error(header: text[..<headerEnd], rest: text[headerEnd...])
        }

        // A RISC OS-style error
        if isRiscOSError(text) {
            return IFLexCompilerError
        }

        // Inform 6's quote of the code an error was for
        if text.first == UInt8(ascii: ">") {
            return IFLexCompilerMessage
        }

        return nil
    }

    /// Scans what follows the header of an Inform 6 error: a label, the spaces after it and the message, or a message
    /// without a label
    private final func scanInform6Error(header: ArraySlice<UInt8>, rest: ArraySlice<UInt8>) -> IFLex? {
        guard let (file, line) = inform6FileAndLine(header) else {
            return nil
        }

        let labels = [("*** Compiler error:", IFLexCompilerFatalError),
                      ("Fatal error:", IFLexCompilerFatalError),
                      ("Error:", IFLexCompilerError),
                      ("Warning:", IFLexCompilerWarning)]

        var type = IFLexCompilerMessage
        var message = rest

        if let (label, labelType) = labels.first(where: { rest.hasPrefix($0.0) }) {
            type = labelType
            message = rest.dropFirst(label.utf8.count).drop { $0 == UInt8(ascii: " ") }
        }

        addError(forFile: file, atLine: line, withType: type, message: String(decoding: message, as: UTF8.self))

        return type
    }

    /// Tells the delegate about an error that Inform 6 gave, and about the page of its own that a known one has
    private final func addError(forFile file: String,
                                atLine line: Int32,
                                withType type: IFLex,
                                message messageString: String) {
        let message = messageString as NSString

        // Look for known error messages
        if type == IFLexCompilerFatalError
            && message.length > memSetting.length
            && message.substring(to: memSetting.length) == memSetting as String {
            delegate?.outputScanner(self, overrideProblemsURL: URL(string: "inform:/ErrorI6MemorySetting.html")!)
        }

        if type == IFLexCompilerFatalError
            && message.length > exceeds.length
            && message.substring(to: exceeds.length) == exceeds as String {
            delegate?.outputScanner(self, overrideProblemsURL: URL(string: "inform:/ErrorI6TooBig.html")!)
        }

        if (type == IFLexCompilerFatalError || type == IFLexCompilerError)
            && message.length > readable.length
            && message.substring(to: readable.length) == readable as String {
            delegate?.outputScanner(self, overrideProblemsURL: URL(string: "inform:/ErrorI6Readable.html")!)
        }

        // Pass the rest to the delegate
        delegate?.outputScanner(self, addErrorForFile: file, atLine: line, withType: type, message: message as String)
    }
}

// == Known errors ==

nonisolated(unsafe) private let memSetting: NSString = "The memory setting "
nonisolated(unsafe) private let exceeds: NSString = "The story file exceeds "
nonisolated(unsafe) private let readable: NSString =
    "This program has overflowed the maximum readable-memory size of the Z-machine format."

// == Inform 6's errors ==

/// Where the header that Inform 6 puts before an error ends, in the format the app asks for, which is
///
///     File "<file>"; Line <line><tab>#<space>
///
/// or, for code after an #OrigSource directive, with where the code came from,
///
///     File "<file>"; Line <line>: (<origin>)<tab>#<space>
///
/// If the line could start with more than one header, this is the longest, as the lexer took it.
private func inform6HeaderEnd(_ text: ArraySlice<UInt8>) -> Int? {
    text.ranges(of: "\t# ".utf8).last { isInform6Header(text[..<$0.lowerBound]) }?.upperBound
}

/// Whether bytes are the header of an Inform 6 error, without the tab and "# " that end it
private func isInform6Header(_ header: ArraySlice<UInt8>) -> Bool {
    guard header.hasPrefix("File \"") else {
        return false
    }

    let lineNumbers = possibleLineNumbers(in: header)

    // File "<file>"; Line <line>
    if lineNumbers.contains(where: { $0.upperBound == header.endIndex }) {
        return true
    }

    // File "<file>"; Line <line>: (<origin>)
    return header.last == UInt8(ascii: ")")
        && lineNumbers.contains { header[$0.upperBound...].hasPrefix(": (") && $0.upperBound + 3 < header.endIndex }
}

/// The file and line that the header of an Inform 6 error gives. The file name ends at the first "; Line  with a line
/// number, and then the tab or ": (" after it.
private func inform6FileAndLine(_ header: ArraySlice<UInt8>) -> (file: String, line: Int32)? {
    for lineNumber in possibleLineNumbers(in: header) {
        let afterLineNumber = header[lineNumber.upperBound...]

        if afterLineNumber.hasPrefix("\t") || afterLineNumber.hasPrefix(": (") {
            let file = header[(header.startIndex + 6) ..< (lineNumber.lowerBound - 8)]
            return (String(decoding: file, as: UTF8.self), number(header[lineNumber]))
        }
    }

    return nil
}

/// Where the line number could be in the header of an Inform 6 error: after each "; Line  that the file name could end
/// with, from the first, the digits after it
private func possibleLineNumbers(in header: ArraySlice<UInt8>) -> [Range<Int>] {
    header.dropFirst(6).ranges(of: "\"; Line ".utf8).compactMap { lineMark in
        let digits = header[lineMark.upperBound...].prefix(while: isDigit)
        return digits.isEmpty ? nil : digits.indices
    }
}

// == Other errors ==

/// Whether a line is a RISC OS-style error: "<file>", line <line>: <message>, or line <line>: <message>
private func isRiscOSError(_ text: ArraySlice<UInt8>) -> Bool {
    func startsWithLine(_ text: ArraySlice<UInt8>) -> Bool {
        guard text.hasPrefix("line ") else {
            return false
        }
        let digits = text.dropFirst(5).prefix(while: isDigit)
        return !digits.isEmpty && text[digits.endIndex...].hasPrefix(": ")
    }

    if startsWithLine(text) {
        return true
    }

    return text.first == UInt8(ascii: "\"")
        && text.dropFirst().ranges(of: "\", ".utf8).contains { startsWithLine(text[$0.upperBound...]) }
}

// == Bytes ==

/// Whether a byte is an ASCII digit
private func isDigit(_ byte: UInt8) -> Bool {
    (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
}

/// The number that some digits give, as atoi gave it to the lexer, even when it's too big for an Int32
private func number(_ digits: ArraySlice<UInt8>) -> Int32 {
    Int32(truncatingIfNeeded: Int(String(decoding: digits, as: UTF8.self)) ?? Int.max)
}

private extension ArraySlice<UInt8> {
    /// Whether the bytes start with a string's UTF-8
    func hasPrefix(_ prefix: String) -> Bool {
        starts(with: prefix.utf8)
    }

    /// Whether the bytes end with a string's UTF-8
    func hasSuffix(_ suffix: String) -> Bool {
        reversed().starts(with: suffix.utf8.reversed())
    }

    /// The bytes between a prefix and a suffix, if they start with one and end with the other, without the two
    /// overlapping
    func between(_ prefix: String, and suffix: String) -> ArraySlice<UInt8>? {
        guard count >= prefix.utf8.count + suffix.utf8.count && hasPrefix(prefix) && hasSuffix(suffix) else {
            return nil
        }
        return dropFirst(prefix.utf8.count).dropLast(suffix.utf8.count)
    }
}
