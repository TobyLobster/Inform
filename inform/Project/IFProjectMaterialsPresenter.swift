//
//  IFProjectMaterialsPresenter.swift
//  Inform
//
//  Created by Toby Nelson in 2014
//  Translated from Objective-C in November 2026. The interface is still IFProjectMaterialsPresenter.h.
//
// This class allows us to read/write to a project's materials folder in a sandboxed app.

import Cocoa

@objc @implementation
extension IFProjectMaterialsPresenter {
    private final let primaryURL: NSURL?
    private final let secondaryURL: NSURL?
    private final let moveURL: NSURL?

    private final let queue: OperationQueue

    @objc(initWithURL:)
    init(url mainURL: URL?) {
        if let mainURL, mainURL.isFileURL {
            primaryURL          = mainURL as NSURL
            secondaryURL        = mainURL.deletingPathExtension().appendingPathExtension("materials") as NSURL
            let moveName        = mainURL.deletingPathExtension().lastPathComponent + " Materials"
            moveURL             = mainURL.deletingLastPathComponent().appendingPathComponent(moveName) as NSURL
        } else {
            primaryURL          = nil
            secondaryURL        = nil
            moveURL             = nil
        }
        queue = OperationQueue()
        super.init()

        if IFUtility.isSandboxed {
            NSFileCoordinator.addFilePresenter(self)
            _ = NSFileCoordinator.filePresenters
        }

        createFolder()
    }

    func close() {
        NSFileCoordinator.removeFilePresenter(self)
    }

    var presentedItemURL: URL? {
        return secondaryURL as URL?
    }

    var presentedItemOperationQueue: OperationQueue {
        return queue
    }

    var primaryPresentedItemURL: URL? {
        return primaryURL as URL?
    }

    private final func createFolder() {
        // Without a file URL, there's nowhere to create it
        guard let secondaryURL = secondaryURL as URL?, let moveURL = moveURL as URL? else {
            NSLog("WARNING: Could not create materials folder at URL (null)")
            return
        }
        let fileManager = FileManager.default

        // move old folder, if present
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: secondaryURL.path) {
            if fileManager.fileExists(atPath: moveURL.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if (try? fileManager.moveItem(at: moveURL, to: secondaryURL)) != nil {
                        let message = String(format: IFUtility.localizedString("Note: This version of Inform stores materials in a '.materials' folder. The folder '%@' has been renamed to '%@'"),
                                             moveURL.lastPathComponent, secondaryURL.lastPathComponent)
                        IFUtility.runAlertInformationWindow(nil,
                                                            title: "Materials folder has been renamed",
                                                            informativeText: message)
                    }
                }
            }
        }

        // Create folder at secondaryURL (the materials folder), if not already there, then set it's icon
        if (try? FileWrapper(url: secondaryURL, options: .withoutMapping)) == nil {
            let wrapper = FileWrapper(directoryWithFileWrappers: [:])

            do {
                try wrapper.write(to: secondaryURL, options: .atomic, originalContentsURL: nil)
            } catch {
                NSLog("WARNING: Could not create materials folder at URL %@", secondaryURL as NSURL)
                return
            }
        }

        // Add icon to folder
        let image = NSImage(named: "materialsfile")
        let didSetIcon = NSWorkspace.shared.setIcon(image,
                                                    forFile: secondaryURL.path,
                                                    options: [])
        if !didSetIcon {
            NSLog("Could not set icon for materials folder at URL %@", secondaryURL as NSURL)
        }
    }
}
