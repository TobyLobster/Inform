//
//  IFProjectFile.swift
//  Inform
//
//  Created by Andrew Hunter on Fri Sep 12 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//  Translated from Objective-C in November 2026. The interface is still IFProjectFile.h.
//

import Cocoa

@objc @implementation
extension IFProjectFile {
    private final let bundleDirectory: FileWrapper

    private final func createUUID() {
        if bundleDirectory.fileWrappers?["uuid.txt"] == nil {
            // Generate a UUID string
            bundleDirectory.addRegularFile(withContents: Data(UUID().uuidString.utf8),
                                           preferredFilename: "uuid.txt")
        }
    }

    // MARK: - Empty project creation

    init(emptyProject: ()) {
        // First we have to create the source directory, etc
        let srcDir   = FileWrapper(directoryWithFileWrappers: [:])
        let bldDir   = FileWrapper(directoryWithFileWrappers: [:])
        let indexDir = FileWrapper(directoryWithFileWrappers: [:])
        srcDir.preferredFilename = "Source"
        bldDir.preferredFilename = "Build"
        indexDir.preferredFilename = "Index"

        bundleDirectory = FileWrapper(directoryWithFileWrappers: ["Source": srcDir,
                                                                  "Build": bldDir,
                                                                  "Index": indexDir])
        super.init()

        createUUID()
    }

    init?(fileWrapper: FileWrapper) {
        if !fileWrapper.isDirectory {
            return nil
        }

        bundleDirectory = fileWrapper
        super.init()

        let sourceDirectory: FileWrapper
        let buildDirectory: FileWrapper
        if let source = fileWrapper.fileWrappers?["Source"] {
            sourceDirectory = source
        } else {
            sourceDirectory = FileWrapper(directoryWithFileWrappers: [:])
            sourceDirectory.preferredFilename = "Source"
        }
        if let build = fileWrapper.fileWrappers?["Build"] {
            buildDirectory = build
        } else {
            buildDirectory = FileWrapper(directoryWithFileWrappers: [:])
            buildDirectory.preferredFilename = "Build"
        }

        bundleDirectory.addFileWrapper(sourceDirectory)
        bundleDirectory.addFileWrapper(buildDirectory)

        createUUID()
    }

    func addSourceFile(_ filename: String, withContents contents: Data) {
        sourceDirectory?.addRegularFile(withContents: contents,
                                        preferredFilename: filename)
    }

    var settings: IFCompilerSettings? {
        get {
            guard let settingsFile = bundleDirectory.fileWrappers?["Settings.plist"] else {
                // Old-style loading
                guard let oldSettingsFile = bundleDirectory.fileWrappers?["Settings"] else {
                    return nil
                }
                if !oldSettingsFile.isRegularFile {
                    // A folder has no settings to read
                    return IFCompilerSettings()
                }

                return IFCompilerSettings(fromOldStyleData: oldSettingsFile.regularFileContents)
            }

            // New-style loading
            let newSettings = IFCompilerSettings()

            // A folder has no settings to read
            if settingsFile.isRegularFile, let contents = settingsFile.regularFileContents {
                _ = newSettings.restore(fromPlist: contents)
            }

            return newSettings
        }
        set {
            // Add the settings plist to the wrapper
            if let settingsPlist = bundleDirectory.fileWrappers?["Settings.plist"] {
                bundleDirectory.removeFileWrapper(settingsPlist)
            }

            let settingsData = newValue?.currentPlist

            // No settings are written as an empty file
            bundleDirectory.addRegularFile(withContents: settingsData ?? Data(),
                                           preferredFilename: "Settings.plist")

            // Delete the old-style file, if it exists
            if let settingsFile = bundleDirectory.fileWrappers?["Settings"] {
                bundleDirectory.removeFileWrapper(settingsFile)
            }
        }
    }

    var sourceDirectory: FileWrapper? {
        // The project's Source folder now, which reloading may have replaced
        let sourceDirectory = bundleDirectory.fileWrappers?["Source"]
        return sourceDirectory?.isDirectory == true ? sourceDirectory : nil
    }

    // Load the notes (if present)
    var loadNotes: NSTextStorage? {
        let noteWrapper = bundleDirectory.fileWrappers?["notes.rtf"]
        if let data = noteWrapper?.regularFileContents {
            return NSTextStorage(rtf: data, documentAttributes: nil)
        }
        return nil
    }

    private final func loadIntoSkein(_ skein: IFSkein, fromFile skeinFilename: String) -> Bool {
        let skeinWrapper = bundleDirectory.fileWrappers?[skeinFilename]
        if let data = skeinWrapper?.regularFileContents {
            _ = skein.parseXmlData(data)

            // Set the root command to the title of the project
            skein.rootItem.command = ((bundleDirectory.preferredFilename as NSString?)?.lastPathComponent as NSString?)?.deletingPathExtension

            skein.activeItem = nil
            skein.postChanged(withAnimate: false,
                              keepActiveVisible: false)
            return true
        }
        return false
    }

    @objc(loadIntoSkeins:project:isExtensionProject:)
    func load(into skeins: NSMutableArray,
              project: IFProject,
              isExtensionProject: Bool) {
        if !isExtensionProject {
            let skein = IFSkein(project: project)
            if loadIntoSkein(skein, fromFile: "Skein.skein") {
                skeins.add(skein)
            }
        }
        else {
            // Load all skeins for an extension project
            let wrappers = bundleDirectory.fileWrappers ?? [:]
            for alphabetCount in 0..<26 {
                let fileToFind = String(format: "Skein%c.skein", Int32(UInt8(ascii: "A")) + Int32(alphabetCount))
                // The file of that name in any case, or the one named exactly if a disk that tells case apart has more
                let names = wrappers.keys.sorted().filter {
                    wrappers[$0]?.isRegularFile == true && ($0 as NSString).isEqual(toStringCaseInsensitive: fileToFind)
                }
                guard let name = names.contains(fileToFind) ? fileToFind : names.first else {
                    break
                }
                let skein = IFSkein(project: project)
                guard loadIntoSkein(skein, fromFile: name) else {
                    break
                }
                skeins.add(skein)
            }
        }

        // If no skein found, use a new one
        if skeins.count == 0 {
            let skein = IFSkein(project: project)

            // Set the root command to the title of the project
            skein.rootItem.command = ((bundleDirectory.preferredFilename as NSString?)?.lastPathComponent as NSString?)?.deletingPathExtension

            skeins.add(skein)
        }
    }

    var loadWatchpoints: NSMutableArray? {
        // Load the watchpoints file (if present)
        let watchWrapper = bundleDirectory.fileWrappers?["Watchpoints.plist"]
        if let data = watchWrapper?.regularFileContents {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                    options: [],
                                                                    format: &format)
            guard let array = plist as? NSArray else {
                return nil
            }
            return array.mutableCopy() as? NSMutableArray
        }
        return nil
    }

    var loadBreakpoints: NSMutableArray? {
        // Load the breakpoints file (if present)
        let breakWrapper = bundleDirectory.fileWrappers?["Breakpoints.plist"]
        if let data = breakWrapper?.regularFileContents {
            var format = PropertyListSerialization.PropertyListFormat.xml
            let plist = try? PropertyListSerialization.propertyList(from: data,
                                                                    options: [],
                                                                    format: &format)
            guard let array = plist as? NSArray else {
                return nil
            }
            return array.mutableCopy() as? NSMutableArray
        }
        return nil
    }

    var loadUUID: String? {
        let uuidWrapper = bundleDirectory.fileWrappers?["uuid.txt"]
        if let data = uuidWrapper?.regularFileContents {
            // The file's contents don't end with a NUL, so they can't be read as a C string
            let uuidString = String(data: data, encoding: .utf8)
            return uuidString
        }
        return nil
    }

    func replaceSourceDirectoryWrapper(_ newWrapper: FileWrapper?) {
        // Replace the source file wrapper
        if let source = bundleDirectory.fileWrappers?["Source"] {
            bundleDirectory.removeFileWrapper(source)
        }
        if let newWrapper {
            bundleDirectory.addFileWrapper(newWrapper)
        }
    }

    func replaceIndexDirectoryWrapper(_ newWrapper: FileWrapper?) {
        // Replace the index file wrapper
        if let index = bundleDirectory.fileWrappers?["Index"] {
            bundleDirectory.removeFileWrapper(index)
        }
        if let newWrapper {
            bundleDirectory.addFileWrapper(newWrapper)
        }
    }

    @objc(replaceWrapper:)
    func replace(_ newWrapper: FileWrapper?) {
        // Remove all old items
        while let wrapper = bundleDirectory.fileWrappers?.values.first {
            bundleDirectory.removeFileWrapper(wrapper)
        }

        // Add new items
        let itemsToAdd = newWrapper?.fileWrappers ?? [:]
        for (_, item) in itemsToAdd {
            bundleDirectory.addFileWrapper(item)
        }
    }

    func writeNotes(_ noteData: Data?) {
        if let notes = bundleDirectory.fileWrappers?["notes.rtf"] {
            bundleDirectory.removeFileWrapper(notes)
        }
        // No notes are written as an empty file
        bundleDirectory.addRegularFile(withContents: noteData ?? Data(),
                                       preferredFilename: "notes.rtf")
    }

    private final func writeSkein(_ xmlString: String, toFilename: String) {
        // The skein file
        let fullXMLString = "<?xml version=\"1.0\"?>\n" + xmlString
        let skeinData = Data(fullXMLString.utf8)

        if let skein = bundleDirectory.fileWrappers?[toFilename] {
            bundleDirectory.removeFileWrapper(skein)
        }
        bundleDirectory.addRegularFile(withContents: skeinData,
                                       preferredFilename: toFilename)
    }

    @objc(writeSkeins:isExtensionProject:)
    func write(_ skeins: [IFSkein], isExtensionProject: Bool) {
        if isExtensionProject {
            // Write all skeins for an extension project
            var alphabetCount = 0
            for skein in skeins {
                if alphabetCount >= 26 {
                    break
                }
                let toFilename = String(format: "Skein%c.skein", Int32(UInt8(ascii: "A")) + Int32(alphabetCount))
                writeSkein(skein.xmlString, toFilename: toFilename)
                alphabetCount += 1
            }
        }
        else {
            // Set the root command to the title of the project
            skeins[0].rootItem.command = ((bundleDirectory.preferredFilename as NSString?)?.lastPathComponent as NSString?)?.deletingPathExtension
            writeSkein(skeins[0].xmlString, toFilename: "Skein.skein")
        }
    }

    func writeWatchpoints(_ watchExpressions: [Any]) {
        // The watchpoints file
        if let watchpoints = bundleDirectory.fileWrappers?["Watchpoints.plist"] {
            bundleDirectory.removeFileWrapper(watchpoints)
        }

        if watchExpressions.count > 0 {
            let watchData = try? PropertyListSerialization.data(fromPropertyList: watchExpressions,
                                                                format: .xml,
                                                                options: 0)

            bundleDirectory.addRegularFile(withContents: watchData ?? Data(),
                                           preferredFilename: "Watchpoints.plist")
        }
    }

    func writeBreakpoints(_ breakpoints: [Any]) {
        // The breakpoints file
        if let breakpointsFile = bundleDirectory.fileWrappers?["Breakpoints.plist"] {
            bundleDirectory.removeFileWrapper(breakpointsFile)
        }

        if breakpoints.count > 0 {
            let breakData = try? PropertyListSerialization.data(fromPropertyList: breakpoints,
                                                                format: .xml,
                                                                options: 0)

            bundleDirectory.addRegularFile(withContents: breakData ?? Data(),
                                           preferredFilename: "Breakpoints.plist")
        }
    }

    @objc(cleanOutUnnecessaryFiles:)
    func cleanOutUnnecessaryFiles(alsoCleanIndex: Bool) {
        // Clean out the build folder from the project
        if let oldBuild = bundleDirectory.fileWrappers?["Build"] {
            bundleDirectory.removeFileWrapper(oldBuild)
        }

        // Replace it with an empty directory
        let build = FileWrapper(directoryWithFileWrappers: [:])
        build.preferredFilename = "Build"
        bundleDirectory.addFileWrapper(build)

        // There may also be a 'Temp' directory: remove that too (no need to recreate this)
        if let temp = bundleDirectory.fileWrappers?["Temp"] {
            bundleDirectory.removeFileWrapper(temp)
        }

        // Clean out the index folder from the project
        if alsoCleanIndex {
            if let oldIndex = bundleDirectory.fileWrappers?["Index"] {
                bundleDirectory.removeFileWrapper(oldIndex)
            }

            // Replace it with an empty directory
            let index = FileWrapper(directoryWithFileWrappers: [:])
            index.preferredFilename = "Index"
            bundleDirectory.addFileWrapper(index)
        }
    }

    var filename: String? {
        get {
            return bundleDirectory.filename
        }
        set {
            bundleDirectory.filename = newValue
        }
    }

    var write: Bool {
        // Without a filename there's nowhere to write
        guard let filename else {
            return false
        }
        let writeToURL = URL(fileURLWithPath: filename)

        do {
            try bundleDirectory.write(to: writeToURL,
                                      options: [.atomic, .withNameUpdating],
                                      originalContentsURL: nil)
            return true
        } catch {
            return false
        }
    }
}
