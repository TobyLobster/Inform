//
//  IFExtensionDownload.swift
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFExtensionDownload.h.
//

import Cocoa

@objc @implementation
extension IFExtensionDownload {
    var state: IFExtensionDownloadState
    var connection: URLSessionDataTask?
    var receivedData: NSMutableData?
    var window: NSWindow?
    var javascriptId: String?
    var notifyDelegate: NSObject?
    var url: URL {
        get {
            return urlObject as URL
        }
        set {
            urlObject = newValue as NSURL
        }
    }

    /// The URL, kept as an object, as `@implementation` can't store a `URL`
    private final var urlObject: NSURL
    private final var urlSession: URLSession?
    /// The server's error, if it gave one: the task is cancelled, and this is reported when it completes
    private final var serverError: NSError?

    @objc(initWithURL:window:notifyDelegate:javascriptId:)
    init(url: URL,
         window aWindow: NSWindow?,
         notifyDelegate: NSObject?,
         javascriptId: String?) {
        self.urlObject      = url as NSURL
        self.state          = .downloadNotStarted
        self.window         = aWindow
        self.receivedData   = NSMutableData()
        self.notifyDelegate = notifyDelegate
        self.javascriptId   = javascriptId
        super.init()
    }

    // MARK: - Download and Install

    @objc(startDownloadAndInstall)
    func startAndInstall() -> Bool {
        // Create the request
        let theRequest = URLRequest(url: url,
                                    cachePolicy: .useProtocolCachePolicy,
                                    timeoutInterval: 10.0)

        // The session keeps this download until it's invalidated, once the task is finished
        let urlSession = URLSession(configuration: .ephemeral,
                                    delegate: self,
                                    delegateQueue: nil)
        self.urlSession = urlSession

        // Create the connection with the request and start loading the data
        connection = urlSession.dataTask(with: theRequest)
        state      = .downloadInProgress

        // Start the task
        connection?.resume()

        return true
    }

    // *******************************************************************************************
    @MainActor private final func downloadedTask(_ task: URLSessionTask, error: Error?) {
        let mgr = IFExtensionsManager.sharedNaturalInform

        if let error {
            //let file = (error as NSError).userInfo[NSURLErrorFailingURLStringErrorKey]

            // Log message
            let message = String(format: IFUtility.localizedString("Failed to Download Extension Explanation - %@"),
                                 error.localizedDescription)

            mgr.addError(message)

            state        = .downloadFailed
            connection   = nil
            receivedData = nil

            mgr.downloadAndInstallFinished(self)
            return
        }

        // Get temporary filename
        let temporaryDirectory = String(cString: (NSTemporaryDirectory() as NSString).fileSystemRepresentation)
        var tempFilename = Array((temporaryDirectory + "temp.XXXXXX.zip").utf8CString)
        let result = mkstemps(&tempFilename, 4)
        if result != -1 {
            // Only the name is needed: the file is written below
            close(result)

            let filename = FileManager.default.string(withFileSystemRepresentation: tempFilename,
                                                      length: strlen(tempFilename))
            // Save the data to a temporary file
            if receivedData?.write(toFile: filename,
                                   atomically: true) == true {
                // Install this extension in the project it was downloaded for, whose page started the download
                let url = URL(fileURLWithPath: filename, isDirectory: false)
                let projectController = notifyDelegate as? IFProjectController
                var installing = false
                if let projectController, let project = projectController.document as? IFProject {
                    if let name = task.originalRequest?.url?.lastPathComponent,
                       let extensionURL = IFNewExtensionsManager.shared.copy(withUnzip: url,
                                                                             toProjectTemporary: project,
                                                                             extensionName: name) {
                        // Call inbuild to check it's a valid extension and install
                        projectController.installExtensionURL(extensionURL)
                        installing = true
                    } else {
                        let message = String(format: IFUtility.localizedString("Failed to Install Extension Explanation - Could not unzip '%@'"),
                                             self.url.lastPathComponent)
                        mgr.addError(message)
                    }
                } else {
                    // The project has been closed
                    mgr.addError(IFUtility.localizedString("Failed to Install Extension Explanation - No project"))
                }

                // Remove temporary file
                try? FileManager.default.removeItem(atPath: filename)

                // Only report success if the extension was handed over to be installed
                state = installing ? .downloadAndInstallSucceeded : .installFailed
            }
            else {
                state = .installFailed
                // Log error
                let message = String(format: IFUtility.localizedString("Failed to Install Extension Explanation - Could not write to file '%@'"),
                                     filename)
                mgr.addError(message)
            }
        }
        else {
            state = .installFailed
            mgr.addError(IFUtility.localizedString("Failed to Install Extension Explanation - Could not make temporary filename"))
        }

        connection   = nil
        receivedData = nil

        mgr.downloadAndInstallFinished(self)
    }
}

// The session's queue uses the task, its data and the server's error only between the task's start and its
// completion, and the main thread only before it starts and once its completion is handed to the main queue
extension IFExtensionDownload: @unchecked Sendable {}

// *******************************************************************************************
extension IFExtensionDownload: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if dataTask === connection {
            if let response = response as? HTTPURLResponse {
                let statusCode = response.statusCode
                if statusCode >= 400 {
                    let localizedStringForStatusCode = HTTPURLResponse.localizedString(forStatusCode: statusCode)
                    let errorInfo = [NSLocalizedDescriptionKey: String(format: IFUtility.localizedString("Server returned status code %d, local string %@"),
                                                                       Int32(statusCode), localizedStringForStatusCode)]
                    serverError = NSError(domain: "Error",
                                          code: statusCode,
                                          userInfo: errorInfo)
                    completionHandler(.cancel) // stop connecting: the task completes, cancelled
                    return
                }
            }

            // This method is called when the server has determined that it
            // has enough information to create the NSURLResponse object.

            // It can be called multiple times, for example in the case of a
            // redirect, so each time we reset the data.

            receivedData?.length = 0
        }
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive data: Data) {
        if dataTask === connection {
            // do something with the data object.
            receivedData?.append(data)
        }
    }

    // *******************************************************************************************
    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        if task === connection {
            // Let go of the session, so that it lets go of this download
            session.finishTasksAndInvalidate()

            // A task cancelled after the server's error reports that error
            let error = serverError ?? error

            // Process the downloaded data on the main thread
            DispatchQueue.main.async {
                self.downloadedTask(task, error: error)
            }
        }
    }
}
