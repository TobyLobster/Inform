//
//  IFCompiler.swift
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFCompiler.h, which
//  also defines the notification names.
//
//  This does the actual low level work of a build: executing tasks in background threads and
//  sending notifications with the results.
//

import Foundation

/// Counts the temporary output files made, so that each has its own name
@MainActor private var mod: UInt32 = 0

/// A build stage waiting to be run
private struct IFCompilerStage {
    let command: String
    let arguments: [String]
    /// The input file for the stage after this one
    let nextStageInput: String
    let name: String
    let problemHandler: IFCompilerProblemHandler?
}

@objc @implementation
extension IFCompiler {
    // The task
    /// Task where the compiler is running
    private final var theTask: Process?

    // Settings, input, output
    /// Settings for the compiler
    var settings: IFCompilerSettings?
    /// `true` if compiling for release
    private final var release: Bool
    /// `true` if compiling for releaseForTesting;
    private final var releaseForTesting: Bool
    /// The input file for this compiler
    var inputFile: String?
    /// The output filename for this compiler
    private final var _outputFile: String?
    /// The working directory for this stage
    var directory: String?
    /// `true` if the output file should be deleted when the compiler is dealloced
    private final var deleteOutputFile: Bool

    /// The URL of the problems page we should show
    private final var _problemsURL: NSURL?
    /// The current problem handler
    private final var problemHandler: IFCompilerProblemHandler?

    // Queue of processes to run
    /// Queue of tasks to run to produce the end result
    private final var runQueue: [IFCompilerStage]

    // Output/input streams
    /// stdErr pipe
    private final var stdErr: Pipe?
    /// stdOut pipe
    private final var stdOut: Pipe?

    /// File handle for stderr
    private final var stdErrH: FileHandle?
    /// File handle for stdout
    private final var stdOutH: FileHandle?

    /// The start of a character at the end of what was read from stderr, kept until the rest arrives
    private final var stdErrPending: Data
    /// The start of a character at the end of what was read from stdout, kept until the rest arrives
    private final var stdOutPending: Data

    /// When =3, the task has finished: its stdout and stderr have ended, and it has terminated
    private final var finishCount: Int32

    // Progress
    /// Progress indicator for compilation
    let progress: IFProgress
    /// Message to show at end of tasks
    var endTextString: String?

    var preferences: IFPreferences

    // MARK: - Initialisation, etc

    override init() {
        release = false
        releaseForTesting = false
        deleteOutputFile = true
        runQueue = []
        stdErrPending = Data()
        stdOutPending = Data()
        finishCount = 0
        progress = IFProgress(priority: IFProgressPriorityCompiler,
                              showsProgressBar: true,
                              canCancel: false)
        preferences = IFPreferences.shared
        super.init()
    }

    deinit {
        // NSDocument can let go of a project, and so its compiler, on another thread after it has closed, as it can
        // a file opened on its own. Tidying up is main-actor work, so it's only done when a compiler is let go of on
        // the main thread, as the project controller's are.
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                if deleteOutputFile { deleteOutput() }

                NotificationCenter.default.removeObserver(self)
            }
        }
    }

    // MARK: - Setup

    func setBuild(forRelease willRelease: Bool, forTesting testing: Bool) {
        release = willRelease
        releaseForTesting = testing
    }

    func deleteOutput() {
        if let outputFile = _outputFile {
            if FileManager.default.fileExists(atPath: outputFile) {
                NSLog("Removing '%@'", outputFile)
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: outputFile, isDirectory: false))
            } else {
                NSLog("Compiler produced no output")
                // Nothing to do
            }

            _outputFile = nil
        }
    }

    func addCustomBuildStage(_ command: String,
                             withArguments arguments: [String],
                             nextStageInput file: String,
                             errorHandler handler: IFCompilerProblemHandler?,
                             named stageName: String) {
        if let theTask {
            // This starts a new build process, so we kill the old task if it's still
            // running
            if theTask.isRunning {
                theTask.terminate()
            }
            self.theTask = nil
        }

        runQueue.append(IFCompilerStage(command: command,
                                        arguments: arguments,
                                        nextStageInput: file,
                                        name: stageName,
                                        problemHandler: handler))
    }

    func addNaturalInformStage(usingTestCase testCase: String?) {
        // The compiler is given settings and an input file before its stages are added.
        // (Without them, Objective-C raised.)
        let settings = settings!

        // Prepare the arguments
        var args = settings.naturalInformCommandLineArguments

        args.append("-\(IFUtility.compilerProjectParameterName(settings.compilerVersion))")
        args.append(currentStageInput!)

        var formatValue = settings.fileExtension
        var debugValue = ""

        if IFUtility.compilerVersion(settings.compilerVersion, isAfter: "6M62") {
            if (formatValue as NSString).isEqual(toStringCaseInsensitive: "z8") {
                formatValue = "Inform6/16"
            } else {
                formatValue = "Inform6/32"
            }
            if !release {
                debugValue = "d"
            }
        }
        args.append("-\(IFUtility.compilerFormatParameterName(settings.compilerVersion))=\(formatValue)\(debugValue)")

        if release && !releaseForTesting {
            args.append("-release")
        }

        if settings.nobbleRng && !release {
            args.append("-rng")
        }

        if settings.basicInform {
            args.append("-basic")
        }

        if let testCase, !testCase.isEmpty {
            args.append("-case")
            args.append(testCase)
        }

        // (The check before this stage is added makes sure there's an Inform 7. Objective-C raised without one.)
        addCustomBuildStage(settings.naturalInformCompilerToUse!,
                            withArguments: args,
                            nextStageInput: "\(currentStageInput!)/Build/auto.inf",
                            errorHandler: NaturalProblem(),
                            named: IFUtility.localizedString("Compiling Natural Inform source"))
    }

    func addStandardInformStage() {
        if _outputFile == nil { _ = outputFile }

        // The compiler is given settings and an input file before its stages are added.
        // (Without them, or an Inform 6, Objective-C raised.)
        let settings = settings!

        // Prepare the arguments
        var args = settings.commandLineArguments(forRelease: release,
                                                 forTesting: releaseForTesting)

        args.append(currentStageInput!)
        args.append(_outputFile!)

        addCustomBuildStage(settings.inform6CompilerToUse!,
                            withArguments: args,
                            nextStageInput: _outputFile!,
                            errorHandler: Inform6Problem(),
                            named: IFUtility.localizedString("Compiling Inform 6 source"))
    }

    var currentStageInput: String? {
        if let stage = runQueue.last {
            return stage.nextStageInput
        }

        return inputFile
    }

    @objc(running)
    var isRunning: Bool {
        @objc(isRunning)
        get {
            return theTask?.isRunning ?? false
        }
    }

    private final func quoteIfNeeded(_ arg: String) -> String {
        if arg.contains(" ") {
            return "\"\(arg)\""
        }
        return arg
    }

    private final func sendTaskDetails(_ task: Process) {
        var taskMessage = "Launching: \(quoteIfNeeded(task.launchPath!))"

        for arg in task.arguments ?? [] {
            taskMessage += " \\\n    \(quoteIfNeeded(arg))"
        }

        taskMessage += "\n"
        sendStdOut(taskMessage, withStyle: IFStyleLaunch)
    }

    private final func prepareNext() {
        let stage = runQueue.removeFirst()
        progress.message = stage.name

        problemHandler = stage.problemHandler

        // Prepare the task
        let theTask = Process()
        self.theTask = theTask
        finishCount = 0

        theTask.arguments = stage.arguments
        theTask.launchPath = stage.command
        if let directory {
            theTask.currentDirectoryPath = directory
        } else {
            theTask.currentDirectoryPath = NSTemporaryDirectory()
        }

        // Prepare the task's IO
        NotificationCenter.default.removeObserver(self)

        let stdErr = Pipe()
        let stdOut = Pipe()
        self.stdErr = stdErr
        self.stdOut = stdOut

        theTask.standardOutput = stdOut
        theTask.standardError = stdErr

        let stdErrH = stdErr.fileHandleForReading
        let stdOutH = stdOut.fileHandleForReading
        self.stdErrH = stdErrH
        self.stdOutH = stdOutH

        stdErrPending = Data()
        stdOutPending = Data()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(stdOutWaiting(_:)),
                                               name: .NSFileHandleDataAvailable,
                                               object: stdOutH)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(stdErrWaiting(_:)),
                                               name: .NSFileHandleDataAvailable,
                                               object: stdErrH)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(taskDidFinish(_:)),
                                               name: Process.didTerminateNotification,
                                               object: theTask)

        stdOutH.waitForDataInBackgroundAndNotify()
        stdErrH.waitForDataInBackgroundAndNotify()
    }

    func prepareForLaunch(withBlorbStage makeBlorb: Bool, testCase: String?) -> Bool {
        // Kill off any old tasks...
        if let theTask {
            if theTask.isRunning {
                theTask.terminate()
            }
            self.theTask = nil
        }

        // There are no problems
        _problemsURL = nil

        if deleteOutputFile { deleteOutput() }

        // Prepare the arguments
        if runQueue.count <= 0 {
            // Check there's an Inform 7 before queuing anything, so nothing's left queued for the next build when
            // there isn't. (With no settings, there's no valid path.)
            guard let settings, settings.isNaturalInformCompilerPathValid() else {
                return false
            }

            if preferences.runBuildSh && !IFUtility.isSandboxed {
                let buildsh = ("~/build.sh" as NSString).expandingTildeInPath

                addCustomBuildStage(buildsh,
                                    withArguments: [],
                                    nextStageInput: currentStageInput!,
                                    errorHandler: nil,
                                    named: "Debug build stage")
            }

            addNaturalInformStage(usingTestCase: testCase)

            addStandardInformStage()

            if makeBlorb {
                // Blorb files kind of create an exception: we change our output file, for instance,
                // and the input file is determined by the blurb file output by NI
                let blorbExtension: String

                if settings.zcodeVersion > 128 {
                    blorbExtension = "gblorb"
                } else {
                    blorbExtension = "zblorb"
                }

                // Work out the new output file
                let oldOutput: String = outputFile
                let newOutput = ((oldOutput as NSString).deletingPathExtension as NSString).appendingPathExtension(blorbExtension)!

                // Work out where the blorb is coming from
                let buildDir   = (currentStageInput! as NSString).deletingLastPathComponent
                let projectdir = (buildDir as NSString).deletingLastPathComponent
                let blorbFile  = (projectdir as NSString).appendingPathComponent("Release.blurb")

                // Add a cBlorb stage
                // (The app always has cBlorb. Objective-C raised without it.)
                let cBlorbLocation = IFUtility.path(forInformExecutable: "cBlorb", version: settings.compilerVersion)!

                addCustomBuildStage(cBlorbLocation,
                                    withArguments: [blorbFile, newOutput],
                                    nextStageInput: newOutput,
                                    errorHandler: CBlorbProblem(buildDir: buildDir),
                                    named: "cBlorb build stage")

                // Change the output file
                outputFile = newOutput
            }
        }

        endTextString = nil
        progress.start()

        prepareNext()
        return true
    }

    func launchWith(inTestStage path: String, command: String, testCase: String) -> Bool {
        // Kill off any old tasks...
        if let theTask {
            if theTask.isRunning {
                theTask.terminate()
            }
            self.theTask = nil
        }

        // There are no problems
        _problemsURL = nil

        if deleteOutputFile { deleteOutput() }

        // Prepare the arguments
        if runQueue.count <= 0 {

            // Add a cBlorb stage
            // (The app always has intest. Objective-C raised without it.)
            let intestLocation = IFUtility.path(forInformExecutable: "intest", version: "")! // Use latest intest

            // The compiler is given settings before an extension is tested. (Without them, Objective-C raised.)
            let settings = settings!

            // (A tool that can't be found is given as "(null)", as Objective-C gave it)
            let inform7Location = IFUtility.path(forCompiler: settings.compilerVersion) ?? "(null)"
            let inform6Location = IFUtility.path(forInformExecutable: "inform6", version: settings.compilerVersion) ?? "(null)"
            let ginterpreterLocation = IFUtility.path(forInformExecutable: "glulxe", version: settings.compilerVersion) ?? "(null)"
            let zinterpreterLocation = IFUtility.path(forInformExecutable: "dumb-frotz", version: settings.compilerVersion) ?? "(null)"
            let fm = FileManager.default

            let results = IFUtility.temporaryDirectoryURL().appendingPathComponent("intest_results.html")
            let workspace = IFUtility.temporaryDirectoryURL().appendingPathComponent("InTestWorkspace")

            do {
                try fm.createDirectory(at: workspace, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return false
            }

            var args: [String] = []
            // intest PATH -internal INTERNAL -results FILE -set 'I7 = ...' -set 'I6 = ...' -set 'GINTERPRETER = ...' -set 'ZINTERPRETER = ...' -workspace WORKSPACE COMMAND CASE
            args.append(path)
            args.append("-internal")
            args.append(IFUtility.path(forInformInternalAppSupport: settings.compilerVersion))
            args.append("-results")
            args.append(results.path)
            args.append("-set")
            args.append("I7COMPILER = \(inform7Location)")
            args.append("-set")
            args.append("I6COMPILER = \(inform6Location)")
            args.append("-set")
            args.append("GINTERPRETER = \(ginterpreterLocation)")
            args.append("-set")
            args.append("ZINTERPRETER = \(zinterpreterLocation)")
            args.append("-workspace")
            args.append(workspace.path)
            args.append(command)
            args.append(testCase)

            let buildDir = (currentStageInput as NSString?)?.deletingLastPathComponent
            addCustomBuildStage(intestLocation,
                                withArguments: args,
                                nextStageInput: results.path,
                                errorHandler: IntestProblem(buildDir: buildDir),
                                named: "Intest build stage")

            // Change the output file
            outputFile = results.path
        }

        endTextString = nil
        progress.start()

        prepareNext()

        // Launch it
        launch()
        return true
    }

    func clearConsole() {
        NotificationCenter.default.post(name: .IFCompilerClearConsole,
                                        object: self)
    }

    func launch() {
        NotificationCenter.default.post(name: .IFCompilerStarting,
                                        object: self)
        // (A stage is always prepared before the compiler is launched)
        start(theTask!)
    }

    /// Starts a stage's task. One that can't be run, as when its command isn't there, ends the build as a stage that
    /// fails does, with the exit code `IFToolRun` gives, and stderr says why.
    private final func start(_ task: Process) {
        sendTaskDetails(task)
        do {
            try task.run()
        } catch {
            let command = task.launchPath ?? "the stage's tool"
            let message = "Couldn't run \(command): \(error.localizedDescription)\n"
            NotificationCenter.default.removeObserver(self)
            NotificationCenter.default.post(name: .IFCompilerStderr,
                                            object: self,
                                            userInfo: ["string": message])

            _problemsURL = nil
            progress.stop()
            progress.message = "Couldn't run \((command as NSString).lastPathComponent)"
            endTextString = nil

            let problemType = stageProblemType
            runQueue.removeAll()
            theTask = nil

            let uiDict: [String: Any] = ["exitCode": NSNumber(value: Int32(-1)),
                                         "problemType": NSNumber(value: problemType.rawValue)]
            NotificationCenter.default.post(name: .IFCompilerFinished,
                                            object: self,
                                            userInfo: uiDict)
        }
    }

    /// The kind of problem the stage's handler gives, for a stage that failed
    private final var stageProblemType: ECompilerProblemType {
        if problemHandler is NaturalProblem {
            return .inform7
        } else if problemHandler is Inform6Problem {
            return .inform6
        } else if problemHandler is CBlorbProblem {
            return .cBlorb
        } else if problemHandler != nil {
            return .unknown
        }
        return .none
    }

    var problemsURL: URL? {
        return _problemsURL as URL?
    }

    var outputFile: String! {
        get {
            if _outputFile == nil {
                mod += 1
                // (With no settings, Objective-C gave the extension as "(null)")
                _outputFile = String(format: "%@/Inform-%x-%x.%@",
                                     NSTemporaryDirectory(), UInt32(truncatingIfNeeded: time(nil)), mod,
                                     settings?.fileExtension ?? "(null)")
                deleteOutputFile = true
            }

            return _outputFile
        }
        set {
            _outputFile = newValue
            deleteOutputFile = false
        }
    }

    private final func taskHasReallyFinished() {
        // (With no task, Objective-C read 0)
        let exitCode = theTask?.terminationStatus ?? 0
        let problemType = exitCode != 0 ? stageProblemType : .none

        if runQueue.count == 0 {
            if exitCode != 0, let problemHandler {
                _problemsURL = problemHandler.urlForProblem(errorCode: exitCode) as NSURL?
            } else if exitCode == 0, let problemHandler {
                if let urlForSuccess = problemHandler.urlForSuccess {
                    _problemsURL = urlForSuccess as NSURL?
                }
            }

            progress.stop()

            // Show final message from compiler
            if let endTextString {
                progress.message = endTextString
                self.endTextString = nil
            }
            let uiDict: [String: Any] = ["exitCode": NSNumber(value: exitCode),
                                         "problemType": NSNumber(value: problemType.rawValue)]
            NotificationCenter.default.post(name: .IFCompilerFinished,
                                            object: self,
                                            userInfo: uiDict)
        } else {
            if exitCode != 0 {
                if let problemHandler {
                    _problemsURL = problemHandler.urlForProblem(errorCode: exitCode) as NSURL?
                }

                // The task failed
                progress.stop()

                // Show final message from compiler
                if let endTextString {
                    progress.message = endTextString
                    self.endTextString = nil
                } else {
                    progress.message = "Error code \(exitCode)"
                }

                // Notify everyone of the failure
                let uiDict: [String: Any] = ["exitCode": NSNumber(value: exitCode),
                                             "problemType": NSNumber(value: problemType.rawValue)]
                NotificationCenter.default.post(name: .IFCompilerFinished,
                                                object: self,
                                                userInfo: uiDict)

                // Give up
                runQueue.removeAll()
                theTask = nil

                return
            }

            // Prepare the next task for launch
            if let theTask {
                if theTask.isRunning {
                    theTask.terminate()
                }
                self.theTask = nil
            }

            prepareNext()

            // Launch it
            start(theTask!)
        }
    }

    // MARK: - Notifications

    func sendStdOut(_ data: String, withStyle style: String) {
        let uiDict: [String: Any] = [
            "string": data,
            "style": style
        ]
        NotificationCenter.default.post(name: .IFCompilerStdout,
                                        object: self,
                                        userInfo: uiDict)
    }

    /// Turns what a stage wrote into text. It's read as UTF-8, keeping back the start of a character
    /// at the end until the rest of it arrives, or as Latin-1 if it isn't UTF-8. Empty data, at the end
    /// of the output, gives what was kept back.
    private final func string(from data: Data, pending: inout Data) -> String? {
        pending.append(data)

        var complete = pending.count
        if data.count > 0 {
            // Find the last character's first byte, after at most three continuation bytes
            let bytes = [UInt8](pending)
            var start = complete
            while start > 0 && complete - start < 3 && (bytes[start - 1] & 0xC0) == 0x80 {
                start -= 1
            }

            if start > 0 {
                let first = bytes[start - 1]
                var size = 1
                if (first & 0xE0) == 0xC0 { size = 2 }
                else if (first & 0xF0) == 0xE0 { size = 3 }
                else if (first & 0xF8) == 0xF0 { size = 4 }

                // Keep it back if it's incomplete
                if complete - (start - 1) < size { complete = start - 1 }
            }
        }

        if complete == 0 { return nil }

        var result = NSString(data: pending.prefix(complete),
                              encoding: String.Encoding.utf8.rawValue) as String?
        if result == nil {
            // It isn't UTF-8, so read all of it as Latin-1
            result = NSString(data: pending,
                              encoding: String.Encoding.isoLatin1.rawValue) as String?
            complete = pending.count
        }

        pending.removeSubrange(pending.startIndex ..< pending.startIndex + complete)
        return result
    }

    @objc private func stdOutWaiting(_ not: Notification) {
        if finishCount >= 3 { return }

        let inData = stdOutH!.availableData

        if let newStr = string(from: inData, pending: &stdOutPending), !newStr.isEmpty {
            sendStdOut(newStr,
                       withStyle: IFStyleBase)
        }

        if inData.count > 0 {
            stdOutH!.waitForDataInBackgroundAndNotify()
        } else {
            finishCount += 1

            if finishCount == 3 {
                taskHasReallyFinished()
            }
        }
    }

    @objc private func stdErrWaiting(_ not: Notification) {
        if finishCount >= 3 { return }

        let inData = stdErrH!.availableData

        if let newStr = string(from: inData, pending: &stdErrPending), !newStr.isEmpty {
            let uiDict: [String: Any] = ["string": newStr]
            NotificationCenter.default.post(name: .IFCompilerStderr,
                                            object: self,
                                            userInfo: uiDict)
        }

        if inData.count > 0 {
            stdErrH!.waitForDataInBackgroundAndNotify()
        } else {
            finishCount += 1

            if finishCount == 3 {
                taskHasReallyFinished()
            }
        }
    }

    @objc private func taskDidFinish(_ not: Notification) {
        finishCount += 1

        if finishCount == 3 {
            taskHasReallyFinished()
        }
    }
}
