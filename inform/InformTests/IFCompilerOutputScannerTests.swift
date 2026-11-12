//
//  IFCompilerOutputScannerTests.swift
//  InformTests
//

import XCTest

/// Scanning each line of the compiler's output for its style and what it tells the app
@MainActor
final class IFCompilerOutputScannerTests: XCTestCase, @unchecked Sendable {

    /// What the scanner tells its delegate
    private enum Event: Equatable {
        case progress(Int32, String?)
        case endText(String)
        case error(file: String, line: Int32, type: IFLex, message: String)
        case problemsURL(String)
        case copyBlorb(String)
    }

    /// A delegate that keeps what it's told
    private final class Delegate: NSObject, IFCompilerOutputScannerDelegate {
        var events: [Event] = []

        func outputScanner(_ scanner: IFCompilerOutputScanner, hasProgress percentage: Int32, message: String?) {
            events.append(.progress(percentage, message))
        }

        func outputScanner(_ scanner: IFCompilerOutputScanner, hasEndText endText: String) {
            events.append(.endText(endText))
        }

        func outputScanner(_ scanner: IFCompilerOutputScanner, addErrorForFile file: String, atLine line: Int32,
                           withType type: IFLex, message: String) {
            events.append(.error(file: file, line: line, type: type, message: message))
        }

        func outputScanner(_ scanner: IFCompilerOutputScanner, overrideProblemsURL problemsURL: URL) {
            events.append(.problemsURL(problemsURL.absoluteString))
        }

        func outputScanner(_ scanner: IFCompilerOutputScanner, copyBlorbTo location: String) {
            events.append(.copyBlorb(location))
        }
    }

    private let scanner = IFCompilerOutputScanner()
    private let delegate = Delegate()

    override func setUp() {
        MainActor.assumeIsolated {
            super.setUp()
            scanner.delegate = delegate
        }
    }

    /// Scans a line, checking its style and what the delegate is told
    private func assertLine(_ line: String, _ style: String?, _ events: [Event] = [],
                            file: StaticString = #filePath, lineNumber: UInt = #line) {
        delegate.events = []
        XCTAssertEqual(scanner.style(forLine: line), style, "style", file: file, line: lineNumber)
        XCTAssertEqual(delegate.events, events, "events", file: file, line: lineNumber)
    }

    /// An error that Inform 6 gives for a line of a file, in the format the app asks for, with where the line's code
    /// came from if an #OrigSource directive says
    private func inform6(_ message: String, file: String = "auto.inf", line: Int = 10, from: String? = nil) -> String {
        let origin = from.map { ": (\($0))" } ?? ""
        return "File \"\(file)\"; Line \(line)\(origin)\t# \(message)\n"
    }

    func testCompilerVersions() {
        assertLine("Inform 7 v10.2.0 has started.\n", IFStyleCompilerVersion)
        assertLine("Inform 6.42 for MacOS (10th February 2024)\n", IFStyleCompilerVersion)
    }

    func testProgress() {
        assertLine("++ 45% (Binding rulebooks)\n", IFStyleProgress, [.progress(45, "Binding rulebooks")])
        assertLine("++ 0% (Reading text)\n", IFStyleProgress, [.progress(0, "Reading text")])
        assertLine("++ 100%\n", IFStyleProgress, [.progress(100, nil)])
        assertLine("++ 12% (Étape café)\n", IFStyleProgress, [.progress(12, "Étape café")])
    }

    func testProgressStagesWithBracketsInThem() {
        assertLine("++ 45% (Reading (more) text)\n", IFStyleProgress, [.progress(45, "Reading (more) text")])
        assertLine("++ 45% ()\n", IFStyleProgress, [.progress(45, "")])
    }

    func testLinesThatAreNotQuiteProgress() {
        assertLine("++ 45%  (Reading text)\n", nil)
        assertLine("++ 45% (Reading text) again\n", nil)
        assertLine("++ %\n", nil)
    }

    func testHowTheCompilerEnded() {
        assertLine("++ Ended: Translation succeeded: 13 rooms, 4 things\n", IFStyleCompilerMessage,
                   [.endText("Translation succeeded: 13 rooms, 4 things")])
        assertLine("++ Ended: Translation failed: 2 problems found\n", IFStyleCompilerMessage,
                   [.endText("Translation failed: 2 problems found")])
    }

    func testAnEndWithNothingToSay() {
        assertLine("++ Ended: \n", IFStyleCompilerMessage, [.endText("")])
        assertLine("++ Ended:\n", nil)
    }

    func testInform6Errors() {
        assertLine(inform6("Error:  No such constant as \"foo\""), IFStyleCompilerError,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerError, message: "No such constant as \"foo\"")])
        assertLine(inform6("Error:  Expected ';' but found x", file: "/Projects/Story.inform/Build/auto.inf", line: 12345),
                   IFStyleCompilerError,
                   [.error(file: "/Projects/Story.inform/Build/auto.inf", line: 12345, type: IFLexCompilerError,
                           message: "Expected ';' but found x")])
    }

    func testInform6Warnings() {
        assertLine(inform6("Warning:  Local variable \"x\" declared but not used", line: 3), IFStyleCompilerWarning,
                   [.error(file: "auto.inf", line: 3, type: IFLexCompilerWarning,
                           message: "Local variable \"x\" declared but not used")])
    }

    func testInform6FatalErrors() {
        assertLine(inform6("Fatal error: Couldn't open source file \"Story.inf\""), IFStyleCompilerFatalError,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerFatalError,
                           message: "Couldn't open source file \"Story.inf\"")])
    }

    func testInform6CompilerErrors() {
        assertLine(inform6("*** Compiler error:  Paged size exceeds rough estimate."), IFStyleCompilerFatalError,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerFatalError,
                           message: "Paged size exceeds rough estimate.")])
    }

    func testInform6ErrorsInCodeThatCameFromElsewhere() {
        // As Inform 6.45 gives it, for code after an #OrigSource directive, which Inform 7 writes
        assertLine("File \"err.inf\"; Line 4: (\"source/story.ni\"; Line 12)\t# Error:  No such constant as \"undefined_thing\"\n",
                   IFStyleCompilerError,
                   [.error(file: "err.inf", line: 4, type: IFLexCompilerError,
                           message: "No such constant as \"undefined_thing\"")])
        assertLine(inform6("Warning:  Local variable \"x\" declared but not used", line: 7,
                           from: "\"Basic Inform.i7x\"; Line 3; Char 5"),
                   IFStyleCompilerWarning,
                   [.error(file: "auto.inf", line: 7, type: IFLexCompilerWarning,
                           message: "Local variable \"x\" declared but not used")])
        assertLine(inform6("Error:  Oops", line: 8, from: "\"BasicInformKit\""), IFStyleCompilerError,
                   [.error(file: "auto.inf", line: 8, type: IFLexCompilerError, message: "Oops")])
    }

    func testAKnownErrorInCodeThatCameFromElsewhere() {
        let message = "This program has overflowed the maximum readable-memory size of the Z-machine format. See below."
        assertLine(inform6("Error:  \(message)", from: "\"source/story.ni\"; Line 12"), IFStyleCompilerError,
                   [.problemsURL("inform:/ErrorI6Readable.html"),
                    .error(file: "auto.inf", line: 10, type: IFLexCompilerError, message: message)])
    }

    func testAFileWithQuotesInItsName() {
        let file = "/Projects/A \"Quoted\" Story.inform/Build/auto.inf"
        assertLine(inform6("Error:  Oops", file: file), IFStyleCompilerError,
                   [.error(file: file, line: 10, type: IFLexCompilerError, message: "Oops")])
        assertLine(inform6("Error:  Oops", file: file, from: "\"source/story.ni\"; Line 12"), IFStyleCompilerError,
                   [.error(file: file, line: 10, type: IFLexCompilerError, message: "Oops")])
    }

    func testAFileWithATabInItsName() {
        assertLine(inform6("Error:  Oops", file: "A\tB.inf"), IFStyleCompilerError,
                   [.error(file: "A\tB.inf", line: 10, type: IFLexCompilerError, message: "Oops")])
    }

    func testAFileWithNoName() {
        assertLine(inform6("Error:  Oops", file: ""), IFStyleCompilerError,
                   [.error(file: "", line: 10, type: IFLexCompilerError, message: "Oops")])
    }

    func testTheLongestHeaderIsTaken() {
        // A message that seems to end another header loses its start, though Inform 6 puts no tabs in its messages
        assertLine(inform6("Error:  Expected \"; Line 2\t# x\" here"), IFStyleCompilerMessage,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerMessage, message: "x\" here")])
    }

    func testOtherInform6Messages() {
        assertLine(inform6("Something else entirely", line: 5), IFStyleCompilerMessage,
                   [.error(file: "auto.inf", line: 5, type: IFLexCompilerMessage, message: "Something else entirely")])
    }

    func testAnInform6MessageNeedsItsLabelFirst() {
        assertLine(inform6("Not an Error:  Oops"), IFStyleCompilerMessage,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerMessage, message: "Not an Error:  Oops")])
    }

    func testAnErrorThatRunsOutOfMemoryHasAPageOfItsOwn() {
        let message = "The memory setting MAX_STATIC_DATA (which is 10000 at present) has been exceeded."
        assertLine(inform6("Fatal error: \(message)"), IFStyleCompilerFatalError,
                   [.problemsURL("inform:/ErrorI6MemorySetting.html"),
                    .error(file: "auto.inf", line: 10, type: IFLexCompilerFatalError, message: message)])
    }

    func testAStoryFileThatIsTooBigHasAPageOfItsOwn() {
        let message = "The story file exceeds version-8 limit (512K) by 1024 bytes"
        assertLine(inform6("Fatal error: \(message)"), IFStyleCompilerFatalError,
                   [.problemsURL("inform:/ErrorI6TooBig.html"),
                    .error(file: "auto.inf", line: 10, type: IFLexCompilerFatalError, message: message)])
    }

    func testOverflowingReadableMemoryHasAPageOfItsOwn() {
        let message = "This program has overflowed the maximum readable-memory size of the Z-machine format. "
            + "See the memory map below: the start of the area marked \"above readable memory\" must be brought "
            + "down to $FFFE or less."
        assertLine(inform6("Error:  \(message)"), IFStyleCompilerError,
                   [.problemsURL("inform:/ErrorI6Readable.html"),
                    .error(file: "auto.inf", line: 10, type: IFLexCompilerError, message: message)])
        assertLine(inform6("Fatal error: \(message)"), IFStyleCompilerFatalError,
                   [.problemsURL("inform:/ErrorI6Readable.html"),
                    .error(file: "auto.inf", line: 10, type: IFLexCompilerFatalError, message: message)])
    }

    func testTheKnownErrorsNeedTheRightKindOfMessage() {
        let tooBig = "The story file exceeds version-8 limit (512K) by 1024 bytes"
        let memory = "The memory setting MAX_STATIC_DATA (which is 10000 at present) has been exceeded."
        let readable = "This program has overflowed the maximum readable-memory size of the Z-machine format. See below."

        assertLine(inform6("Error:  \(tooBig)"), IFStyleCompilerError,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerError, message: tooBig)])
        assertLine(inform6("Warning:  \(memory)"), IFStyleCompilerWarning,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerWarning, message: memory)])
        assertLine(inform6("Warning:  \(readable)"), IFStyleCompilerWarning,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerWarning, message: readable)])
    }

    func testALineThatIsNotAnInform6ErrorAfterAll() {
        assertLine("File \"auto.inf\"; Line ten\n", nil)
        // The next line is scanned afresh
        assertLine("Inform 7 v10.2.0 has started.\n", IFStyleCompilerVersion)
        assertLine(inform6("Error:  Oops"), IFStyleCompilerError,
                   [.error(file: "auto.inf", line: 10, type: IFLexCompilerError, message: "Oops")])
    }

    func testRiscOSStyleErrors() {
        assertLine("\"auto.inf\", line 10: Error: No such constant\n", IFStyleCompilerError)
        assertLine("line 10: Error: No such constant\n", IFStyleCompilerError)
    }

    func testLinesThatAreNotQuiteInform6Errors() {
        assertLine("File \"auto.inf\"; Line 10\t#Error:  Oops\n", nil)
        assertLine("File \"auto.inf\"; Line 10 # Error:  Oops\n", nil)
        assertLine("File \"auto.inf\"; Line 10: (BasicInformKit\t# Error:  Oops\n", nil)
    }

    func testLinesThatAreNotQuiteRiscOSStyleErrors() {
        assertLine("line 10:Error: No such constant\n", nil)
        assertLine("\"auto.inf\" line 10: Error: No such constant\n", nil)
    }

    func testLinesThatAreMessages() {
        assertLine("> look\n", IFStyleCompilerMessage)
        assertLine(">\n", IFStyleCompilerMessage)
    }

    func testWhereCblorbAsksForTheBlorbFileToBeCopied() {
        assertLine("Copy blorb to: [[/Users/me/Release/Bronze Materials/Bronze.gblorb]]\n", IFStyleCompilerMessage,
                   [.copyBlorb("/Users/me/Release/Bronze Materials/Bronze.gblorb")])
    }

    func testBlorbLocationsWithBracketsInThem() {
        assertLine("Copy blorb to: [[/Release/A]]B.gblorb]]\n", IFStyleCompilerMessage,
                   [.copyBlorb("/Release/A]]B.gblorb")])
        assertLine("Copy blorb to: [[]]\n", IFStyleCompilerMessage, [.copyBlorb("")])
    }

    func testLinesThatAreNotQuiteBlorbLocations() {
        assertLine("Copy blorb to: [[/Release/Story.gblorb]] now\n", nil)
        assertLine("Copy blorb to: [/Release/Story.gblorb]\n", nil)
    }

    func testOtherLinesAreLeftAsTheyAre() {
        assertLine("Compiling Inform 6 source...\n", nil)
        assertLine("  Inform 7 v10.2.0\n", nil)
        assertLine("++ Starting\n", nil)
        assertLine("\n", nil)
        assertLine("", nil)
    }

    func testLinesWithoutTheirNewline() {
        assertLine("Inform 7 v10.2.0 has started.", IFStyleCompilerVersion)
        assertLine("++ 45% (Reading text)", nil)
        assertLine("++ Ended: Translation succeeded", nil)
        assertLine("Copy blorb to: [[/Release/Story.gblorb]]", nil)
        assertLine("\"auto.inf\", line 10: Error: No such constant", nil)
        assertLine("> look", nil)
    }

    func testEachScannerTellsItsOwnDelegate() {
        let other = IFCompilerOutputScanner()
        let otherDelegate = Delegate()
        other.delegate = otherDelegate

        XCTAssertEqual(scanner.style(forLine: "++ 10% (Reading text)\n"), IFStyleProgress)
        XCTAssertEqual(other.style(forLine: inform6("Error:  Oops")), IFStyleCompilerError)
        XCTAssertEqual(scanner.style(forLine: "Copy blorb to: [[/Release/Story.gblorb]]\n"), IFStyleCompilerMessage)

        XCTAssertEqual(delegate.events, [.progress(10, "Reading text"), .copyBlorb("/Release/Story.gblorb")])
        XCTAssertEqual(otherDelegate.events,
                       [.error(file: "auto.inf", line: 10, type: IFLexCompilerError, message: "Oops")])
    }

    func testAScannerWithoutADelegateStillGivesTheStyles() {
        let alone = IFCompilerOutputScanner()

        XCTAssertEqual(alone.style(forLine: "++ 10% (Reading text)\n"), IFStyleProgress)
        XCTAssertEqual(alone.style(forLine: inform6("Fatal error: The story file exceeds version-8 limit")),
                       IFStyleCompilerFatalError)
        XCTAssertEqual(alone.style(forLine: "Copy blorb to: [[/Release/Story.gblorb]]\n"), IFStyleCompilerMessage)
    }
}
