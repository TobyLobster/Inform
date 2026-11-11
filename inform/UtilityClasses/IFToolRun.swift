//
//  IFToolRun.swift
//  Inform
//
//  Moved out of IFInBuild and IFInTest in November 2026. The interface is IFToolRun.h.
//

import Foundation

@objc @implementation
extension IFToolRun {
    let standardOutput: Data
    let standardError: Data
    let exitCode: Int32

    init(command: String?, arguments: [String]) {
        // Prepare the task (based on
        // http://stackoverflow.com/questions/412562/execute-a-terminal-command-from-a-cocoa-app )
        let theTask = Process()

        theTask.arguments = arguments
        theTask.launchPath = command
        theTask.currentDirectoryPath = NSTemporaryDirectory()

        // Prepare the task's IO
        let stdErrPipe = Pipe()
        let stdOutPipe = Pipe()

        theTask.standardOutput = stdOutPipe
        theTask.standardError = stdErrPipe
        theTask.standardInput = Pipe()       // "The magic line that keeps your log where it belongs"

        let stdOutH = stdOutPipe.fileHandleForReading
        let stdErrH = stdErrPipe.fileHandleForReading

        // Start the task
        theTask.launch()

        // Wait until finished
        var data = Data(capacity: 512)
        while theTask.isRunning {
            data.append(stdOutH.readDataToEndOfFile())
        }
        data.append(stdOutH.readDataToEndOfFile())

        // Record output
        standardOutput = data
        standardError = stdErrH.readDataToEndOfFile()
        exitCode = theTask.terminationStatus
        super.init()
    }
}
