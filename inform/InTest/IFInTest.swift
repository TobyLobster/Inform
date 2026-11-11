//
//  IFInTest.swift
//  Inform
//
//  Created by Toby Nelson in 2015
//  Translated from Objective-C in November 2026. The interface is still IFInTest.h.
//

import Foundation

private struct ConcordancePair {
    var left: Int32
    var right: Int32
}

private struct IFTestCaseData {
    // Concordance data
    var concordance: [ConcordancePair] = []
}

@objc @implementation
extension IFInTest {
    // Results
    private final var stdOut: String?
    private final var stdErr: String?

    private final var exitCode: Int32

    /// Data for each test case
    private final var testCaseData: [String: IFTestCaseData]

    // == Initialisation, etc ==

    override init() {
        exitCode = 0
        testCaseData = [:]
        super.init()
    }

    private final func tidyUp() {
        exitCode    = 0
        stdErr      = nil
        stdOut      = nil
    }

    // MARK: - Setup

    private final func executeInTest(forExtension extensionPathName: String,
                                     withArgs args: [String]) {
        var mutableArgs = args
        mutableArgs.insert(((extensionPathName as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent,
                           at: 0)

        // nil if the app hasn't got intest, when the run says so
        let command = IFUtility.path(forInformExecutable: "intest", version: "")

        // InTest Start notification
        var uiDict: [String: Any] = ["args": mutableArgs]
        if let command {
            uiDict["command"] = command
        }
        NotificationCenter.default.post(name: .IFInTestStarting,
                                        object: self,
                                        userInfo: uiDict)

        stdErr = ""
        stdOut = ""

        let run = IFToolRun(command: command, arguments: mutableArgs)

        // Record output
        stdOut = NSString(data: run.standardOutput,
                          encoding: String.Encoding.utf8.rawValue) as String?
        stdErr = NSString(data: run.standardError,
                          encoding: String.Encoding.utf8.rawValue) as String?
        exitCode = run.exitCode

        // intest always writes UTF-8, so the output is never nil. (Objective-C raised on nil, as here.)
        // Stdout
        uiDict = ["string": stdOut!]
        NotificationCenter.default.post(name: .IFInTestStdout,
                                        object: self,
                                        userInfo: uiDict)

        // Stderr
        uiDict = ["string": stdErr!]
        NotificationCenter.default.post(name: .IFInTestStderr,
                                        object: self,
                                        userInfo: uiDict)

        // InTest Finished Notification
        uiDict = ["exitCode": NSNumber(value: exitCode)]
        NotificationCenter.default.post(name: .IFInTestFinished,
                                        object: self,
                                        userInfo: uiDict)
    }

    func extractSourceTask(forExtensionFile extensionPathName: String,
                           forTestCase testCase: String,
                           outputToSourceFile sourcePathName: String) {
        let args     = [ "-no-history",
                         "-threads=1",
                         "-using",
                         "-extension",   extensionPathName,
                         "-do",
                         "-source",      testCase,
                         "-to",          sourcePathName,
                         "-concordance", testCase ]
        executeInTest(forExtension: extensionPathName, withArgs: args)

        // Parse concordance
        var data = IFTestCaseData()

        if exitCode == 0 {
            let lines = (stdOut ?? "").components(separatedBy: "\n")
            for line in lines {
                let equalsIndex = (line as NSString).index(of: " ")
                if equalsIndex != NSNotFound {
                    let left  = ((line as NSString).substring(to: equalsIndex) as NSString).trimmingWhitespace
                    let right = ((line as NSString).substring(from: equalsIndex + 1) as NSString).trimmingWhitespace
                    let pair = ConcordancePair(left: (left as NSString).intValue,
                                               right: (right as NSString).intValue)
                    data.concordance.append(pair)
                }
            }
        }

        testCaseData[testCase] = data

        // Task is completed - tidy up.
        tidyUp()
    }

    func refreshExtensionCatalogue(_ extensionPathName: String) -> [[String: Any]] {

        // Get latest catalogue
        let args     = ["-no-history",
                        "-threads=1",
                        "-using",
                        "-extension", extensionPathName,
                        "-do",
                        "-catalogue" ]
        executeInTest(forExtension: extensionPathName, withArgs: args)

        // Interpret results
        var testCases: [[String: Any]] = []

        if exitCode == 0 {
            let lines = (stdOut ?? "").components(separatedBy: "\n")
            for line in lines {
                if (line as NSString).starts(with: "extension ") {
                    let buffer = [unichar(UInt8(ascii: "A")) + unichar(testCases.count)]
                    let key = NSString(characters: buffer, length: 1) as String

                    // intest gives no title for an example whose source doesn't start with one
                    var title = "Example \(key)"
                    let equalsIndex = (line as NSString).index(of: "=")
                    if equalsIndex != NSNotFound {
                        title = ((line as NSString).substring(from: equalsIndex + 1) as NSString).trimmingWhitespace
                    }
                    testCases.append([ "testKey": key,
                                       "testTitle": title ])
                }
            }
        }

        // Task is completed - tidy up.
        tidyUp()

        return testCases
    }

    func testCommands(forExtension extensionPathName: String,
                      testCase: String) -> String? {
        // Get latest catalogue
        let args     = ["-no-history",
                        "-threads=1",
                        "-using",
                        "-extension", extensionPathName,
                        "-do",
                        "-script", testCase ]
        executeInTest(forExtension: extensionPathName, withArgs: args)

        // Interpret results
        var results: String? = nil
        if exitCode == 0 {
            results = stdOut
        }

        tidyUp()
        return results
    }

    func generateReport(forExtension extensionPathName: String,
                        testCase: String,
                        errorCode: String,
                        problemsURL: URL,
                        skeinNodeId: UInt,
                        skeinNodes: Int32,
                        outputURL: URL) -> Int32 {
        // Get latest catalogue
        let args     = ["-no-history",
                        "-threads=1",
                        "-using",
                        "-extension", extensionPathName,
                        "-do",
                        "-report",
                        testCase,
                        errorCode,
                        problemsURL.path,
                        "n\(skeinNodeId)",
                        "t\(skeinNodes)",
                        "-to",
                        outputURL.path]
        executeInTest(forExtension: extensionPathName, withArgs: args)
        let result = exitCode

        tidyUp()
        return result
    }

    func generateCombinedReport(forExtension extensionPathName: String,
                                baseInputURL: URL,
                                numTests: Int32,
                                outputURL: URL) -> Int32 {
        // Get latest catalogue
        let args     = ["-no-history",
                        "-threads=1",
                        "-using",
                        "-extension", extensionPathName,
                        "-do",
                        "-combine",
                        baseInputURL.path,
                        "-\(numTests)",
                        "-to",
                        outputURL.path]
        executeInTest(forExtension: extensionPathName, withArgs: args)
        let result = exitCode

        tidyUp()
        return result
    }

    func adjustLine(_ lineNumber: Int32, forTestCase testCase: String) -> Int32 {
        if let data = testCaseData[testCase] {
            for pair in data.concordance.reversed() {
                if lineNumber >= pair.left {
                    return lineNumber + pair.right
                }
            }
        }
        return lineNumber
    }
}
