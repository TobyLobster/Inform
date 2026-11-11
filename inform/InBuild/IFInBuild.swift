//
//  IFInBuild.swift
//  Inform
//
//  Created by Toby Nelson in 2023
//  Translated from Objective-C in November 2026. The interface is still IFInBuild.h.
//

import Foundation

/// The text with the characters that HTML takes as markup escaped, so that an error page shows it as written.
/// No text is "(null)", as Objective-C's `%@` wrote it.
private func escapedForHTML(_ text: String?) -> String {
    guard let text else {
        return "(null)"
    }
    return text.replacingOccurrences(of: "&", with: "&amp;")
               .replacingOccurrences(of: "<", with: "&lt;")
               .replacingOccurrences(of: ">", with: "&gt;")
}

@objc @implementation
extension IFInBuild {
    private final var exitCode: Int32

    private final var _stdOut: NSMutableString?
    private final var _stdErr: NSMutableString?

    var stdOut: NSMutableString? {
        return _stdOut
    }
    var stdErr: NSMutableString? {
        return _stdErr
    }

    override init() {
        exitCode = 0
        super.init()
    }

    // MARK: - Setup

    private final func executeCommandLine(_ command: String?,
                                          args: [String]) -> String {
        _stdErr = NSMutableString()
        _stdOut = NSMutableString()

        var message = ""
        message += "Current Directory: \(NSTemporaryDirectory())\n"
        message += "Command: \(command ?? "(null)")\n"
        message += "Args: "
        for arg in args {
            let hasSpaces = ((arg as NSString).index(of: " ") != NSNotFound)
            if hasSpaces { message += "'" }
            message += arg
            if hasSpaces { message += "'" }
            message += "\n      "
        }
        NSLog("%@", message)

        let run = IFToolRun(command: command, arguments: args)

        // Record output
        _stdOut = NSString(data: run.standardOutput,
                           encoding: String.Encoding.utf8.rawValue)?.mutableCopy() as? NSMutableString
        _stdErr = NSString(data: run.standardError,
                           encoding: String.Encoding.utf8.rawValue)?.mutableCopy() as? NSMutableString
        exitCode = run.exitCode

        return message
    }

    @objc(executeInBuildForInfoWithProject:action:forExtension:withInternal:withConfirmation:withResults:settings:)
    func executeForInfo(withProject projectURL: URL,
                        action: String,
                        forExtension extensionURL: URL,
                        withInternal internalURL: URL,
                        withConfirmation confirmed: Bool,
                        withResults resultsURL: URL,
                        settings: IFCompilerSettings) -> Int32 {
        // Build a command with arguments:
        //  inbuild -project PROJECTDIR -install EXTENSION -results RESULTS

        var mutableArgs: [String] = []
        mutableArgs.append("-project")
        mutableArgs.append(projectURL.path)
        mutableArgs.append(action)
        mutableArgs.append(extensionURL.path)
        mutableArgs.append("-results")
        mutableArgs.append(resultsURL.path)
        mutableArgs.append("-internal")
        mutableArgs.append(internalURL.path)

        if settings.allowLegacyExtensionDirectory {
            let externalPath = IFUtility.pathForInformExternalAppSupport()
            mutableArgs.append("-deprecated-external")
            mutableArgs.append(externalPath)
        }

        if confirmed {
            mutableArgs.append("-confirmed")
        }

        let command = IFUtility.path(forInformExecutable: "inbuild", version: settings.compilerVersion)

        let message = executeCommandLine(command,
                                         args: mutableArgs)

        if exitCode != 0 {
            // Write error messaging as HTML page to resultsURL
            let errorHTML = String(format: "<HTML><head><meta charset=\"UTF-8\"></head><body>There was an error running inbuild:<br><pre>%@\nstdout: %@\nstderr: %@exit code: %d</pre></body></html>",
                                   escapedForHTML(message), escapedForHTML(stdOut as String?), escapedForHTML(stdErr as String?), exitCode)

            try? errorHTML.write(toFile: resultsURL.path,
                                 atomically: false,
                                 encoding: .utf8)
        }
        NSLog("stdout: %@", (stdOut as String?) ?? "(null)")
        NSLog("stderr: %@", (stdErr as String?) ?? "(null)")
        NSLog("exit code: %d", exitCode)
        return exitCode
    }

    @objc(executeInBuildForCensus)
    func executeForCensus() -> Int32 {
        var externalPath = IFUtility.pathForInformExternalAppSupport()
        externalPath = (externalPath as NSString).appendingPathComponent("Extensions")

        let internalPath = IFUtility.path(forInformInternalAppSupport: "")

        // Build a command with arguments:
        // inbuild -inspect -recursive -contents-of ~/Library/Inform/Extensions

        var mutableArgs: [String] = []
        mutableArgs.append("-inspect")
        mutableArgs.append("-recursive")
        mutableArgs.append("-contents-of")
        mutableArgs.append(externalPath)
        mutableArgs.append("-internal")
        mutableArgs.append(internalPath)
        mutableArgs.append("-json")
        mutableArgs.append("-")

        // Use latest inbuild
        let command = IFUtility.path(forInformExecutable: "inbuild", version: "")

        _ = executeCommandLine(command,
                               args: mutableArgs)

        NSLog("stdout: %@", (stdOut as String?) ?? "(null)")
        NSLog("stderr: %@", (stdErr as String?) ?? "(null)")
        NSLog("exit code: %d", exitCode)

        return exitCode
    }

    @objc(executeInBuildForConvertingMarkdown:toHTML:withInternal:settings:)
    func execute(forConvertingMarkdown markdownFilepath: String,
                 toHTML htmlFilepath: String,
                 withInternal internalURL: URL,
                 settings: IFCompilerSettings) -> Int32 {
        // Build a command with arguments:
        // inbuild -internal INTERNAL -markdown-from MARKDOWNFILE -markdown-to HTMLFILE

        var mutableArgs: [String] = []
        mutableArgs.append("-internal")
        mutableArgs.append(internalURL.path)
        mutableArgs.append("-markdown-from")
        mutableArgs.append(markdownFilepath)
        mutableArgs.append("-markdown-to")
        mutableArgs.append(htmlFilepath)

        let command = IFUtility.path(forInformExecutable: "inbuild", version: settings.compilerVersion)

        let message = executeCommandLine(command,
                                         args: mutableArgs)

        if exitCode != 0 {
            // Write error messaging as HTML page to resultsURL
            let errorHTML = String(format: "<HTML><head><meta charset=\"UTF-8\"></head><body>There was an error running inbuild:<br><pre>%@\nstdout: %@\nstderr: %@exit code: %d</pre></body></html>",
                                   escapedForHTML(message), escapedForHTML(stdOut as String?), escapedForHTML(stdErr as String?), exitCode)

            try? errorHTML.write(toFile: htmlFilepath,
                                 atomically: false,
                                 encoding: .utf8)
        }
        NSLog("stdout: %@", (stdOut as String?) ?? "(null)")
        NSLog("stderr: %@", (stdErr as String?) ?? "(null)")
        NSLog("exit code: %d", exitCode)
        return exitCode
    }
}
