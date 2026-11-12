//
//  IFExtensionTestCases.swift
//  Inform
//
//  Moved out of IFProject in November 2026. The interface is IFExtensionTestCases.h.
//

import Foundation

@objc @implementation extension IFExtensionTestCases {

    let inTest: IFInTest

    private final var _testCases: [[String: Any]]?

    override init() {
        inTest      = IFInTest()
        _testCases  = nil

        super.init()
    }

    // == intest ==
    @objc(refreshTestCasesForExtension:)
    func refreshTestCases(forExtension extensionPathName: String?) {
        _testCases = []

        guard let extensionPathName else {
            return
        }

        _testCases = inTest.refreshExtensionCatalogue(extensionPathName)
    }

    var testCases: [[String: Any]]? {
        return _testCases
    }

    func extractSourceTask(forExtensionTestCase testCase: String?,
                           fromExtension extensionPathName: String,
                           outputToSourceFile sourcePathName: String) {
        guard let testCase else {
            return
        }

        inTest.extractSourceTask(forExtensionFile: extensionPathName,
                                 forTestCase: testCase,
                                 outputToSourceFile: sourcePathName)
    }

    func testCommands(forExtensionTestCase testCase: String,
                      ofExtension extensionPathName: String) -> [String]? {
        let commandString = inTest.testCommands(forExtension: extensionPathName,
                                                testCase: testCase)
        guard let commandString = (commandString as NSString?)?.removingTrailingWhitespace else {
            return nil
        }
        return commandString.components(separatedBy: "\n")
    }

    class var baseReportURL: URL {
        let fileName = "Inform-Report.html"
        return IFUtility.temporaryDirectoryURL().appendingPathComponent(fileName)
    }

    @objc(reportURLForTestCaseAtIndex:)
    class func reportURL(forTestCaseAt index: Int) -> URL {
        let fileName = "Inform-Report-\(index + 1).html"
        return IFUtility.temporaryDirectoryURL().appendingPathComponent(fileName)
    }

    func generateReport(forTestCase testCase: String,
                        ofExtension extensionPathName: String,
                        errorCode: String,
                        problemsURL: URL,
                        skeinNodeId: UInt,
                        skeinNodes: Int32,
                        outputURL: URL) -> Bool {
        let exitCode = inTest.generateReport(forExtension: extensionPathName,
                                             testCase: testCase,
                                             errorCode: errorCode,
                                             problemsURL: problemsURL,
                                             skeinNodeId: skeinNodeId,
                                             skeinNodes: skeinNodes,
                                             outputURL: outputURL)
        if exitCode == 0 {
            return true
        }

        NSLog("Intest report returned exit code %d\n", exitCode)
        return false
    }

    // Outputs an HTML report that combinines the individual reports
    func generateCombinedReport(forBaseInputURL baseInputURL: URL,
                                ofExtension extensionPathName: String,
                                numTests: Int32,
                                outputURL: URL) -> Bool {
        let exitCode = inTest.generateCombinedReport(forExtension: extensionPathName,
                                                     baseInputURL: baseInputURL,
                                                     numTests: numTests,
                                                     outputURL: outputURL)
        if exitCode == 0 {
            return true
        }

        NSLog("Intest combined report returned exit code %d\n", exitCode)
        return false
    }

    // Extension project compilation problems need redirecting back to extension.i7x source, not story.ni
    func redirectLinks(toExtensionSourceCode link: [Any],
                       inExtensionProject isExtensionProject: Bool) -> [Any] {
        if link.count == 3 {
            if isExtensionProject {
                if let file = link[0] as? NSString, file.isEqual(toStringCaseInsensitive: "story.ni") {
                    let lineNumber = link[2] as AnyObject
                    let extensionLineNumber = inTest.adjustLine(lineNumber.intValue,
                                                                forTestCase: link[1] as? String ?? "")
                    return ["extension.i7x", NSNumber(value: extensionLineNumber)]
                }
            }
            // Remove the test case parameter
            return [link[0], link[2]]
        }

        return link
    }
}
