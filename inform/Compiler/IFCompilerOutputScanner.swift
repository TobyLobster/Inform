//
//  IFCompilerOutputScanner.swift
//  Inform
//
//  Moved out of IFCompilerController in November 2026.
//  Translated from Objective-C in November 2026. The interface is still IFCompilerOutputScanner.h.
//

import Foundation

/// The scanner whose line the lexer is scanning, which the lexer's helper functions report to
private var activeScanner: IFCompilerOutputScanner?

@objc @implementation extension IFCompilerOutputScanner {
    weak var delegate: IFCompilerOutputScannerDelegate?

    func style(forLine line: String) -> String? {
        activeScanner = self
        let res = IFLex(rawValue: UInt32(bitPattern: IFErrorScanString(line)))

        switch res {
        case IFLexBase:
            return IFStyleBase

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

        case IFLexAssembly:
            return IFStyleAssembly

        case IFLexHexDump:
            return IFStyleHexDump

        case IFLexStatistics:
            return IFStyleStatistics

        case IFLexProgress:
            var msg: String? = nil

            if let progressString = IFLexLastProgressString {
                msg = NSString(bytes: progressString,
                               length: strlen(progressString) - 2,
                               encoding: String.Encoding.utf8.rawValue) as String?

                // (Second attempt if UTF-8 makes no sense)
                if msg == nil {
                    msg = NSString(bytes: progressString,
                                   length: strlen(progressString) - 2,
                                   encoding: String.Encoding.isoLatin1.rawValue) as String?
                }
            }

            delegate?.outputScanner(self, hasProgress: IFLexLastProgress, message: msg)

            return IFStyleProgress

        case IFLexEndText:
            if let endTextString = IFLexEndTextString {
                var msg = NSString(bytes: endTextString,
                                   length: strlen(endTextString) - 1,
                                   encoding: String.Encoding.utf8.rawValue) as String?

                // (Second attempt if UTF-8 makes no sense)
                if msg == nil {
                    msg = NSString(bytes: endTextString,
                                   length: strlen(endTextString) - 1,
                                   encoding: String.Encoding.isoLatin1.rawValue) as String?
                }

                if let msg {
                    delegate?.outputScanner(self, hasEndText: msg)
                }
            }
            return IFStyleCompilerMessage

        default:
            break
        }

        return nil
    }
}

// == The lexical helper functions, which the lexer calls ==

private let memSetting: NSString = "The memory setting "
private let exceeds: NSString = "The story file exceeds "
private let readable: NSString = "This program has overflowed the maximum readable-memory size of the Z-machine format."

@_cdecl("IFErrorAddError")
func IFErrorAddError(_ filC: UnsafePointer<CChar>,
                     _ line: Int32,
                     _ type: IFLex,
                     _ mesC: UnsafePointer<CChar>) {
    let file    = String(cString: filC)
    let message = String(cString: mesC) as NSString

    guard let scanner = activeScanner else { return }

    // Look for known error messages
    if type == IFLexCompilerFatalError
        && message.length > memSetting.length
        && message.substring(to: memSetting.length) == memSetting as String {
        scanner.delegate?.outputScanner(scanner, overrideProblemsURL: URL(string: "inform:/ErrorI6MemorySetting.html")!)
    }

    if type == IFLexCompilerFatalError
        && message.length > exceeds.length
        && message.substring(to: exceeds.length) == exceeds as String {
        scanner.delegate?.outputScanner(scanner, overrideProblemsURL: URL(string: "inform:/ErrorI6TooBig.html")!)
    }

    if (type == IFLexCompilerFatalError || type == IFLexCompilerError)
        && message.length > readable.length
        && message.substring(to: readable.length) == readable as String {
        scanner.delegate?.outputScanner(scanner, overrideProblemsURL: URL(string: "inform:/ErrorI6Readable.html")!)
    }

    // Pass the rest to the delegate
    scanner.delegate?.outputScanner(scanner,
                                    addErrorForFile: file,
                                    atLine: line,
                                    withType: type,
                                    message: message as String)
}

@_cdecl("IFErrorCopyBlorbTo")
func IFErrorCopyBlorbTo(_ whereTo: UnsafePointer<CChar>) {
    guard let scanner = activeScanner else { return }

    scanner.delegate?.outputScanner(scanner, copyBlorbTo: String(cString: whereTo))
}
