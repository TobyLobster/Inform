//
//  IFExtensionsManager.swift
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//  Translated from Objective-C in November 2026. The interface is still IFExtensionsManager.h.
//

import Cocoa

private let maxErrorMessagesToDisplay: Int32 = 3

private let sharedManager = IFExtensionsManager()

/// The lists of installed extensions: for projects for 6M62 and earlier, from the extension folders,
/// and for later projects, from inbuild's census
private enum ExtensionList {
    case legacy
    case census
}

// *******************************************************************************************
@objc @implementation
extension IFExtensionsManager {
    var rebuildExtensionDictionaryCache: Bool
    var cacheChanged: Bool

    // Collection directories to look
    /// Standard set of extension directories
    private final var extensionCollectionDirectories: [String]

    // Cache data
    /// Caches the extension dictionary until we next clear the cache
    private final var cacheExtensionDictionary: NSDictionary?
    /// Caches each list of available extensions until we next clear the cache
    private final var cacheAvailableExtensions: [ExtensionList: [IFExtensionInfo]]
    /// The lists of available extensions to make again when they're next asked for
    private final var availableExtensionsToRebuild: Set<ExtensionList>
    /// Number of extension dictionaries that are 'installed' to ~/Library/Inform rather than internal to the Inform app bundle resources (i.e. one)
    private final var userLibraryCount: Int

    // Download and install
    /// Mutable array of current downloads
    private final var downloads: [IFExtensionDownload]
    /// How many things we are downloading and installing
    private final var numberOfBatchedExtensions: Int32
    /// Number of failed download / installs
    private final var numberOfErrors: Int32
    /// Multiple error messages are accumulated into this string
    private final var errorString: NSMutableString
    /// Progress
    private final var dlProgress: IFProgress?

    private final var inBuild: IFInBuild

    // MARK: - Shared extension manager

    @objc(sharedNaturalInformExtensionsManager)
    class var sharedNaturalInform: IFExtensionsManager {
        return sharedManager
    }

    // MARK: - Initialisation

    override init() {
        extensionCollectionDirectories = []

        cacheAvailableExtensions = [:]
        cacheExtensionDictionary = nil

        // Get the list of directories where extensions might live

        userLibraryCount = 1

        downloads = []
        numberOfBatchedExtensions = 0
        numberOfErrors = 0
        errorString = NSMutableString()

        availableExtensionsToRebuild = [.legacy, .census]
        rebuildExtensionDictionaryCache = true
        cacheChanged = false

        inBuild = IFInBuild()

        super.init()

        addExtensionCollectionDirectory(IFUtility.pathForInformExternalExtensions())        // External directory of extensions
        addExtensionCollectionDirectory(IFUtility.path(forInformInternalExtensions: ""))    // Internal directory of extensions
    }

    // MARK: - Setting up

    private final func addExtensionCollectionDirectory(_ directory: String) {
        extensionCollectionDirectories.append(directory)
    }

    func dirtyCache() {
        rebuildExtensionDictionaryCache = true
        availableExtensionsToRebuild = [.legacy, .census]
    }

    // Returns a dictionary where key is author name, value is an array of directory paths for that author
    private final func extensionDictionary() -> NSDictionary {
        if !rebuildExtensionDictionaryCache, let cacheExtensionDictionary {
            return cacheExtensionDictionary
        }

        let manager = FileManager.default

        // Retrieve the extensions that exist in the directory
        let resultSet = NSMutableDictionary()

        // Look through the directories
        for extnDir in extensionCollectionDirectories {
            let extnFiles = (try? manager.contentsOfDirectory(atPath: extnDir)) ?? []
            for filename in extnFiles {
                let fullPath = (extnDir as NSString).appendingPathComponent(filename)

                // Must not be hidden from the finder
                if (filename as NSString).character(at: 0) == unichar(UInt8(ascii: ".")) {
                    continue
                }

                // 'reserved' is a special case and never shows up in the list
                if (filename as NSString).lowercased == "reserved" {
                    continue
                }

                // Must exist and be a directory
                var isDir: ObjCBool = false

                let exists = manager.fileExists(atPath: fullPath,
                                                isDirectory: &isDir)

                if exists && isDir.boolValue {
                    // Add to the list of paths for this name
                    let filenameKey = (filename as NSString).lowercased
                    let dirsWithName = resultSet[filenameKey] as? NSMutableArray ?? NSMutableArray()

                    dirsWithName.add(fullPath)

                    // Add to the result
                    resultSet[filenameKey] = dirsWithName
                }
            }
        }

        // Cache the results
        let newExtensionDictionary = resultSet

        // Compare dictionaries
        if !(cacheExtensionDictionary?.isEqual(newExtensionDictionary) ?? false) {
            cacheChanged = true
        }

        cacheExtensionDictionary = newExtensionDictionary
        rebuildExtensionDictionaryCache = false

        return resultSet
    }

    private final func isBuiltIn(_ fullPath: String) -> Bool {
        var count = 0
        for extnDir in extensionCollectionDirectories {
            if (fullPath as NSString).starts(with: extnDir) {
                if count >= userLibraryCount {
                    return true
                }
                return false
            }
            count += 1
        }
        return false
    }

    // Get an array of the available extension information
    func availableExtensions(withCompilerVersion compilerVersion: String) -> [IFExtensionInfo] {
        var result: [IFExtensionInfo] = []
        let list: ExtensionList = IFUtility.compilerVersion(compilerVersion, isAfter: "6M62") ? .census : .legacy

        // Use the cached version if it's around
        if !availableExtensionsToRebuild.contains(list), let cachedExtensions = cacheAvailableExtensions[list] {
            return cachedExtensions
        }

        if list == .census {
            // New extension census. This is only used to populate the
            // menu items for extensions.

            // Step 1: call inbuild to get list of extensions
            inBuild.executeForCensus()

            // Step 2: Parse list of extensions into array
            let text = inBuild.stdOut as String?
            result = parseExtensionsList(text) as? [IFExtensionInfo] ?? []
        } else {
            // Old extension parsing
            let manager = FileManager.default
            let extensionDictionary = self.extensionDictionary()

            // Go through authors
            for (_, authorPathsObject) in extensionDictionary {
                let authorPaths = authorPathsObject as? [String] ?? []

                // For each path of an author
                for authorPath in authorPaths {
                    var title: NSString?
                    var author: NSString?
                    var version: NSString?

                    let extnFiles = (try? manager.contentsOfDirectory(atPath: authorPath)) ?? []
                    // For each extension file
                    for filename in extnFiles {
                        let fullFilepath = (authorPath as NSString).appendingPathComponent(filename)

                        // Must not be hidden from the finder
                        if (filename as NSString).character(at: 0) == unichar(UInt8(ascii: ".")) {
                            continue
                        }

                        let fileExtension = ((filename as NSString).pathExtension as NSString).lowercased
                        if fileExtension == "i7x" ||
                           fileExtension == "" {
                            // Get information about the extension
                            let gotInfo = info(forNaturalInformExtension: fullFilepath,
                                               author: &author,
                                               title: &title,
                                               version: &version)
                            if gotInfo == .success, let title, let author {
                                let isBuiltIn = self.isBuiltIn(fullFilepath)
                                let info = IFExtensionInfo(displayName: title as String,
                                                           filepath: fullFilepath,
                                                           author: author as String,
                                                           version: version as String?,
                                                           isBuiltIn: isBuiltIn)
                                result.append(info)
                            }
                        }
                    }
                }
            }
        }

        // Remember this result in cache
        let newAvailableExtensions = result

        if cacheAvailableExtensions[list] != newAvailableExtensions {
            cacheChanged = true
        }

        cacheAvailableExtensions[list] = newAvailableExtensions
        availableExtensionsToRebuild.remove(list)

        // Tell anything that wants to know that the extensions have been updated
        NotificationCenter.default.post(name: .IFCensusFinished,
                                        object: self)

        return result
    }

    func availableAuthors(withCompilerVersion compilerVersion: String) -> [String] {
        let authors = NSMutableSet()

        for info in availableExtensions(withCompilerVersion: compilerVersion) {
            authors.add(info.author)
        }
        return (authors.allObjects as NSArray).sortedArray(using: #selector(NSString.caseInsensitiveCompare(_:))) as? [String] ?? []
    }

    func availableExtensions(byAuthor author: String,
                             withCompilerVersion compilerVersion: String) -> [IFExtensionInfo] {
        let author = (author as NSString).lowercased
        let extensions = NSMutableArray()

        for info in availableExtensions(withCompilerVersion: compilerVersion) {
            if ((info.author as NSString).lowercased as NSString).isEqual(to: author) {
                extensions.add(info)
            }
        }
        extensions.sort(using: #selector(IFExtensionInfo.caseInsensitiveCompare(_:)))
        return extensions as? [IFExtensionInfo] ?? []
    }

    // Returns the array of full extension pathnames for a given extension directory (author) name
    func filesInExtension(withName name: String) -> [String] {
        // Returns all the files in a particular extension (as full path names)
        let manager = FileManager.default

        // Work out which paths to search (just one if we're not merging)
        let pathsToSearch = extensionDictionary()[(name as NSString).lowercased] as? [String] ?? []

        // Search all the paths to generate the list of files
        // If a file with the same name exists in multiple places, then only the first one is used
        let resultDict = NSMutableDictionary()

        for path in pathsToSearch {
            // Search this path
            let files = (try? manager.contentsOfDirectory(atPath: path)) ?? []
            for file in files {
                // Add to the result, unless it was in an earlier path
                if resultDict[(file as NSString).lowercased] == nil {
                    resultDict[(file as NSString).lowercased] = (path as NSString).appendingPathComponent(file)
                }
            }
        }

        // Sort
        let result = NSMutableArray(array: resultDict.allValues)
        result.sort(using: #selector(NSString.caseInsensitiveCompare(_:)))

        return result.copy() as? [String] ?? []
    }

    // Create directories
    private final func createDirectory(_ dir: String) {
        precondition(dir != "",  "Bad directory in createDirectory (2)")
        precondition(dir != "/", "Bad directory in createDirectory (3)")

        var isDir: ObjCBool = false

        let exists = FileManager.default.fileExists(atPath: dir,
                                                    isDirectory: &isDir)
        if exists { return }

        try? FileManager.default.createDirectory(atPath: dir,
                                                 withIntermediateDirectories: true,
                                                 attributes: nil)
    }

    private final func createDefaultExtnDir() {
        // Create the directory that will contain the extensions (if necessary)
        let directory = extensionCollectionDirectories[0]

        // Create the directory (and the hierarchy)
        createDirectory(directory)
    }

    // Install the given extension
    func installLegacyExtension(_ extensionPath: String,
                                finalPath finalPathOut: UnsafeMutablePointer<NSString?>?,
                                title titleOut: UnsafeMutablePointer<NSString?>?,
                                author authorOut: UnsafeMutablePointer<NSString?>?,
                                version versionOut: UnsafeMutablePointer<NSString?>?,
                                showWarningPrompts: Bool,
                                notify: Bool) -> IFExtensionResult {
        finalPathOut?.pointee = nil

        // We can add directories (of all sorts, but with no subdirectories, and no larger than 1Mb total)
        // We can also add .h, .inf and .i6 files on their own, creating a directory to do so
        let mgr = FileManager.default

        let extensionPath = (extensionPath as NSString).standardizingPath

        createDefaultExtnDir()

        // Check that file or directory exists
        var isDir: ObjCBool = false

        let exists = mgr.fileExists(atPath: extensionPath,
                                    isDirectory: &isDir)
        if !exists || isDir.boolValue {
            return .notFound          // Can't add something that does not exist
        }

        var author: NSString? = nil
        var title: NSString? = nil
        var version: NSString? = nil

        // Check if it is valid to add the file
        // Inform 7 extensions (i7x) have a first line defining title and author (and optional version number)
        // Try to read out the author and title name to see if this file is valid
        var result = info(forNaturalInformExtension: extensionPath,
                          author: &author,
                          title: &title,
                          version: &version)
        if result != .success { return result }

        authorOut?.pointee = author
        titleOut?.pointee = title
        versionOut?.pointee = version

        // We should be able to add the file/directory

        // Try to create the destination. First extensionDirectory should be the writable one
        let directory = extensionCollectionDirectories[0] as NSString
        var destDir: NSString

        if let author {
            destDir = directory.appendingPathComponent(author as String) as NSString
        } else {
            destDir = directory.appendingPathComponent(((extensionPath as NSString).lastPathComponent as NSString).deletingPathExtension) as NSString
        }

        destDir = destDir.standardizingPath as NSString

        if (destDir.lowercased as NSString).isEqual(to: (extensionPath as NSString).lowercased) {
            return .alreadyExists        // Trying to re-add an extension that already exists
        }

        // If the old directory exists and we're not merging, then move the old directory to the trash
        let oldExists = mgr.fileExists(atPath: destDir as String)

        // If the directory does not exist, create it
        if !oldExists {
            do {
                try mgr.createDirectory(atPath: destDir as String,
                                        withIntermediateDirectories: true,
                                        attributes: nil)
            } catch {
                // Can't create the extension directory
                return .cantWriteDestination
            }
        }

        var destFile: NSString

        // Work out the destination filename
        if let title {
            destFile = title
        }
        else {
            destFile = (extensionPath as NSString).lastPathComponent as NSString
        }

        destFile = IFExtensionInfo.canonicalTitle(destFile as String) as NSString

        // destination file mut not be longer than 50 characters? (Is this true?)
        if (destFile.deletingPathExtension as NSString).length > 50 {
            // Extension filenames must be at most 50 characters
            // Remove extension and truncate
            destFile = (destFile.deletingPathExtension as NSString).substring(to: 50) as NSString
        }

        // Extension must have a .i7x extension
        if !(destFile.pathExtension as NSString).isEqual(to: "i7x") {
            destFile = destFile.appendingPathExtension("i7x")! as NSString
        }

        let dest = destDir.appendingPathComponent(destFile as String)
        finalPathOut?.pointee = dest as NSString

        // Are we trying to install over a newer version?
        var existingAuthor: NSString?
        var existingTitle: NSString?
        var existingVersion: NSString?
        result = info(forNaturalInformExtension: dest,
                      author: &existingAuthor,
                      title: &existingTitle,
                      version: &existingVersion)
        if result == .success {
            if showWarningPrompts {
                if let existingTitle, let title,
                   (existingTitle.lowercased as NSString).isEqual(to: title.lowercased) {
                    if let existingAuthor, let author,
                       (existingAuthor.lowercased as NSString).isEqual(to: author.lowercased) {
                        let version = version ?? "Version 1"
                        let existingVersion = existingVersion ?? "Version 1"

                        let comparison = existingVersion.compare(version as String,
                                                                 options: [.numeric, .caseInsensitive])

                        // WARNING: About to overwrite a later version with an earlier one!
                        if comparison == .orderedDescending {
                            let alert = NSAlert()
                            alert.messageText = String(format: IFUtility.localizedString("Overwrite Extension"), existingTitle, existingAuthor)
                            alert.informativeText = String(format: IFUtility.localizedString("Overwrite Extension Explanation"), existingVersion, version)
                            alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
                            let destructive = alert.addButton(withTitle: IFUtility.localizedString("Replace"))
                            destructive.hasDestructiveAction = true
                            let overwrite = alert.runModal()
                            if overwrite != .alertSecondButtonReturn {
                                return .success
                            }
                        }
                        else {
                            // WARNING: About to overwrite on earlier or equal version with a later version.
                            let alert = NSAlert()
                            alert.messageText = String(format: IFUtility.localizedString("Replace Extension"), existingTitle, existingAuthor)
                            alert.informativeText = String(format: IFUtility.localizedString("Replace Extension Explanation"), existingVersion, version)
                            alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
                            let destructive = alert.addButton(withTitle: IFUtility.localizedString("Replace"))
                            destructive.hasDestructiveAction = true
                            let overwrite = alert.runModal()
                            if overwrite != .alertSecondButtonReturn {
                                return .success
                            }
                        }
                    }
                }
            }
        }

        // Remove old file at destination
        do {
            let destFileWithoutExtension = (dest as NSString).deletingPathExtension

            // Try removing the destination file *without* the i7x file extension (remove old version that may not have had a file extension)
            try? mgr.removeItem(atPath: destFileWithoutExtension)

            // Try removing the destination file *with* i7x file extension
            try? mgr.removeItem(atPath: dest)
        }

        // Copy new file to destination
        do {
            try mgr.copyItem(atPath: extensionPath,
                             toPath: dest)
        } catch {
            // Couldn't finish installing the extension
            return .cantWriteDestination
        }

        // Note: this is for Legacy extensions, hence an old version "6M62"
        updateExtensions(forCompilerVersion: "6M62", notify: NSNumber(value: notify))

        // Success
        return .success
    }

    // MARK: - Data source support functions

    private final func updateExtensions(forCompilerVersion compilerVersion: String,
                                        notify: NSNumber) {
        // Calculate fresh available extensions
        dirtyCache()
        _ = availableExtensions(withCompilerVersion: compilerVersion)

        // Has the array of available extensions changed?
        if !cacheChanged {
            return
        }
        cacheChanged = false

        if IFUtility.compilerVersion(compilerVersion, isNoLaterThan: "6M62") {
            // Perform a legacy census with the new extensions
            startLegacyCensus(notify)
        }
    }

    func startLegacyCensus(_ notify: NSNumber) {
        // Re-run the maintenance tasks
        if let compilerPath = IFUtility.path(forCompiler: "") {
            let notifyType: NSNotification.Name
            if notify.boolValue {
                notifyType = .IFCensusFinished
            } else {
                notifyType = .IFCensusFinishedButDontUpdateExtensionsWebPage
            }

            let externalPath = IFUtility.pathForInformExternalAppSupport()
            let arguments = ["-census",
                             "-internal",
                             IFUtility.path(forInformInternalAppSupport: ""),
                             "-external",
                             externalPath]

            NSLog("Compiler Path: %@", compilerPath)
            NSLog("Arguments: %@", arguments as NSArray)

            IFMaintenanceTask.shared.queue(compilerPath,
                                           withArguments: arguments,
                                           notifyType: notifyType)
        }
    }

    // MARK: - Download and Install

    func addError(_ message: String) {
        // Log error
        NSLog("%@", message)

        numberOfErrors += 1

        // Append the new message
        let gap = (numberOfErrors > 1) ? "\n\n" : ""
        if numberOfErrors <= maxErrorMessagesToDisplay {
            errorString.appendFormat("%@%@", gap, message)
        }
        else if numberOfErrors == (maxErrorMessagesToDisplay + 1) {
            errorString.append("\n\n...")
        }
    }

    @objc private func startDownloadAndInstallNextInQueue() {
        if downloads.count > 0 {
            let dl = downloads[0]

            dl.startAndInstall()
        }
    }

    func downloadAndInstallExtension(_ url: URL,
                                     window aWindow: NSWindow?,
                                     notifyDelegate: NSObject?,
                                     javascriptId: String?) -> Bool {
        let download = IFExtensionDownload(url: url,
                                           window: aWindow,
                                           notifyDelegate: notifyDelegate,
                                           javascriptId: javascriptId)
        downloads.append(download)
        numberOfBatchedExtensions += 1

        if downloads.count == 1 {
            // Remove old progress
            if let dlProgress {
                if let controller = download.notifyDelegate as? IFProjectController {
                    dlProgress.stop()
                    controller.removeProgressIndicator(dlProgress)
                }
            }
            // Create new progress
            let progress = IFProgress(priority: IFProgressPriorityExtensions,
                                      showsProgressBar: true,
                                      canCancel: true)
            dlProgress = progress
            if let controller = download.notifyDelegate as? IFProjectController {
                controller.addProgressIndicator(progress)
            }
            progress.message = IFUtility.localizedString("Installing extension")
            progress.start()
            startDownloadAndInstallNextInQueue()
        }
        return true
    }

    func reportDownloadResults(_ download: IFExtensionDownload) {
        // Report errors or success - only if we are not cancelled
        if !(dlProgress?.isCancelled ?? false) {
            // Were there errors? Report them if so.
            if numberOfErrors > 0 {
                if numberOfErrors < numberOfBatchedExtensions {
                    let messageKey: String

                    if (numberOfBatchedExtensions - numberOfErrors) == 1 {
                        messageKey = String(format: IFUtility.localizedString("One extension installed successfully, %d failed"), numberOfErrors)
                    } else {
                        messageKey = String(format: IFUtility.localizedString("%d extensions installed successfully, %d failed"), numberOfBatchedExtensions - numberOfErrors, numberOfErrors)
                    }
                    IFUtility.runAlertWarning(download.window,
                                              localizedTitle: messageKey,
                                              informativeText: errorString as String)
                } else {
                    if numberOfBatchedExtensions > 1 {
                        IFUtility.runAlertWarning(download.window,
                                                  localizedTitle: String(format: IFUtility.localizedString("Failed to install %d extensions"), numberOfErrors),
                                                  informativeText: errorString as String)
                    } else {
                        IFUtility.runAlertWarning(download.window,
                                                  localizedTitle: IFUtility.localizedString("Failed to install extension"),
                                                  informativeText: errorString as String)
                    }
                }
            }
        }

        // Remove progress indicator
        if let controller = download.notifyDelegate as? IFProjectController, let dlProgress {
            dlProgress.stop()
            controller.removeProgressIndicator(dlProgress)
        }

        numberOfBatchedExtensions = 0
        numberOfErrors = 0
        errorString.setString("")
    }

    private final func downloadAndInstallFinishedOnMainThread(_ download: IFExtensionDownload) {
        let done  = numberOfBatchedExtensions - Int32(downloads.count)
        let total = numberOfBatchedExtensions
        let percentage = 100.0 * CGFloat(done) / CGFloat(total)
        let message: String
        if numberOfErrors > 0 {
            message = String(format: IFUtility.localizedString("Installed %d of %d (%d failed)"), done - numberOfErrors, total, numberOfErrors)
        } else {
            message = String(format: IFUtility.localizedString("Installed %d of %d"), done, total)
        }
        dlProgress?.percentage = percentage
        dlProgress?.message = message

        // Remove any remaining items if we are we cancelled
        if dlProgress?.isCancelled ?? false {
            downloads.removeAll()
        }

        // Last one finished downloading?
        if downloads.count == 0 {
            // Report results back on the main thread
            DispatchQueue.main.async {
                self.reportDownloadResults(download)
            }
        }

        // If this particular download succeeded, tell the IFProjectController so it can update the web page to indicate it's downloaded
        if download.state == .downloadAndInstallSucceeded {
            dirtyCache()
            // Make the list again for the project that the extension was installed in
            let project = (download.notifyDelegate as? IFProjectController)?.document as? IFProject
            _ = availableExtensions(withCompilerVersion: project?.settings.compilerVersion ?? "6M62")

            if download.notifyDelegate != nil {
                if let controller = download.notifyDelegate as? IFProjectController {
                    controller.extensionUpdated(download.javascriptId)
                }
            }
            cacheChanged = false
        }
    }

    func downloadAndInstallFinished(_ download: IFExtensionDownload) {
        downloads.removeAll { $0.isEqual(download) }

        DispatchQueue.main.async {
            self.downloadAndInstallFinishedOnMainThread(download)
        }

        if downloads.count > 0 {
            perform(#selector(startDownloadAndInstallNextInQueue),
                    with: nil,
                    afterDelay: 0.5)
        }
    }
}
