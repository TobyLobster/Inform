//
//  IFMaintenanceTask.swift
//  Inform
//
//  Created by Andrew Hunter on 25/04/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFMaintenanceTask.h.
//

import Cocoa

/// The common maintenance task object, made when it's first needed
@MainActor private let sharedMaintenanceTask = IFMaintenanceTask()

/// A task waiting to be run
private struct IFPendingMaintenanceTask {
    let command: URL
    let arguments: [String]
    let notifyType: NSNotification.Name
}

@objc @implementation
extension IFMaintenanceTask {
    /// The task that's currently running
    private final var activeTask: Process?
    /// The tasks that are going to be run
    private final var pendingTasks: [IFPendingMaintenanceTask]
    /// Current notification type for activeTask
    private final var activeTaskNotificationType: NSNotification.Name?

    /// `true` if we've notified of a finish event
    private final var haveFinished: Bool

    // MARK: - Initialisation

    @objc(sharedMaintenanceTask)
    class var shared: IFMaintenanceTask {
        return sharedMaintenanceTask
    }

    override init() {
        activeTask = nil
        activeTaskNotificationType = nil
        pendingTasks = []

        haveFinished = true
        super.init()
    }

    // MARK: - Starting tasks

    private final func startNextTask() -> Bool {
        if activeTask != nil { return true }
        if pendingTasks.count <= 0 { return false }

        // Retrieve the next task to run
        let newTask = pendingTasks.removeFirst()

        // Set up a new task
        let activeTask = Process()
        self.activeTask = activeTask

        activeTask.executableURL = newTask.command
        activeTask.arguments = newTask.arguments
        activeTaskNotificationType = newTask.notifyType

        // Register for notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(taskFinished(_:)),
                                               name: Process.didTerminateNotification,
                                               object: activeTask)

        // Notify anyone who's interested that we're started
        if haveFinished {
            NotificationCenter.default.post(name: .IFMaintenanceTasksStarted,
                                            object: self)
            haveFinished = false
        }

        // Start the task
        activeTask.launch()
        return true
    }

    @objc private func taskFinished(_ not: Notification) {
        // Stop monitoring the old task
        NotificationCenter.default.removeObserver(self,
                                                  name: Process.didTerminateNotification,
                                                  object: activeTask)

        // Clear up the old task
        activeTask = nil

        // Start the next task in the queue
        if !startNextTask() {
            // We've finished!
            haveFinished = true
            if let notifyType = activeTaskNotificationType {
                NotificationCenter.default.post(name: notifyType,
                                                object: self)
                activeTaskNotificationType = nil
            }
        }
    }

    // MARK: - Queuing tasks

    @objc(queueTask:withArguments:notifyType:)
    func queue(_ command: String,
               withArguments arguments: [String],
               notifyType: NSNotification.Name) {
        let commandURL = URL(fileURLWithPath: command)

        // Check if the previous item on the queue is exactly the same command, skip if so.
        if let lastObject = pendingTasks.last {
            if lastObject.command == commandURL &&
                lastObject.arguments == arguments &&
                lastObject.notifyType == notifyType {
                return
            }
        }

        pendingTasks.append(IFPendingMaintenanceTask(command: commandURL,
                                                     arguments: arguments,
                                                     notifyType: notifyType))

        _ = startNextTask()
    }
}
