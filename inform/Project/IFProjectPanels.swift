//
//  IFProjectPanels.swift
//  Inform
//
//  Moved out of IFProject in November 2026. The interface is IFProjectPanels.h.
//

import Cocoa

@objc @implementation extension IFProjectPanels {

    private final let project: IFProject

    init(project: IFProject) {
        self.project = project

        super.init()
    }

    // Save iFiction
    @objc(saveIFictionWithWindow:)
    func saveIFiction(with window: NSWindow) {
        // Work out where the iFiction file should be
        let iFictionURL = project.metadataURL

        // Prompt the user to save the iFiction file if it exists
        if let iFictionURL, FileManager.default.fileExists(atPath: iFictionURL.path) {
            // Setup a save panel
            let panel = NSSavePanel()

            panel.accessoryView = nil
            panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["iFiction"])
            panel.canSelectHiddenExtension = true
            panel.prompt = IFUtility.localizedString("Save iFiction record")
            panel.treatsFilePackagesAsDirectories = false
            panel.directoryURL = project.fileURL?.deletingLastPathComponent()
            panel.nameFieldStringValue = ((project.fileURL?.lastPathComponent ?? "") as NSString).deletingPathExtension

            // Show it
            panel.beginSheetModal(for: window) { result in
                // Copy the file to the specified path
                if result == .OK, let url = panel.url {
                    do {
                        try self.project.saveIFiction(to: url, hidingExtension: panel.isExtensionHidden)
                    } catch {
                        panel.close()
                        NSAlert(error: error).beginSheetModal(for: window)
                    }
                }
            }
        } else {
            // Oops, failed to generate an iFiction record
            IFUtility.runAlertWarning(window,
                                      title: "The compiler failed to produce an iFiction record",
                                      informativeText: IFUtility.localizedString("The compiler failed to create an iFiction record; check the errors page to see why."))
        }
    }

    @objc(saveCompilerOutputWithWindow:)
    func saveCompilerOutput(with window: NSWindow) {
        // Setup a save panel
        let panel = NSSavePanel()

        panel.accessoryView = nil
        panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: [(project.compiler.outputFile as NSString).pathExtension])
        panel.canSelectHiddenExtension = true
        panel.prompt = IFUtility.localizedString("Save")
        panel.treatsFilePackagesAsDirectories = false
        panel.nameFieldStringValue = ((project.fileURL?.lastPathComponent ?? "") as NSString).deletingPathExtension

        // Show it
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let whereToSave = panel.url?.path {
                // Remove existing file then copy
                try? FileManager.default.removeItem(atPath: whereToSave)
                do {
                    try FileManager.default.copyItem(atPath: self.project.compiler.outputFile,
                                                     toPath: whereToSave)
                } catch {
                    panel.close()

                    // File failed to save
                    // Report that a file failed to save
                    let alert = NSAlert()
                    let contents = String(format: IFUtility.localizedString("An error was encountered while trying to save the file '%@'"),
                                          (whereToSave as NSString).lastPathComponent)

                    alert.addButton(withTitle: IFUtility.localizedString("Retry"))
                    alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
                    alert.messageText = IFUtility.localizedString("Unable to save file")
                    alert.informativeText = contents
                    alert.alertStyle = .warning

                    alert.beginSheetModal(for: window) { returnCode in
                        if returnCode == .alertFirstButtonReturn {
                            // Try again, in the same window
                            RunLoop.current.perform(#selector(self.saveCompilerOutput(with:)),
                                                    target: self,
                                                    argument: window,
                                                    order: 128,
                                                    modes: [.default])
                        }
                    }
                    return
                }
            }
        }
    }

    @objc(importIntoSkeinWithWindow:)
    func importIntoSkein(with window: NSWindow) {
        // Set up an open panel
        let importPanel = NSOpenPanel()

        importPanel.accessoryView = nil
        importPanel.canChooseFiles = true
        importPanel.canChooseDirectories = false
        importPanel.resolvesAliases = true
        importPanel.allowsMultipleSelection = false
        importPanel.title = IFUtility.localizedString("Choose a recording, skein or Zoom save game file")
        importPanel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["rec", "txt", "zoomSave", "skein"])

        // Display the panel
        importPanel.beginSheetModal(for: window) { result in
            if result == .OK, let path = importPanel.url?.path {
                if let loadError = self.project.importIntoCurrentSkein(fromFile: path) {
                    importPanel.close()
                    let alert = NSAlert()
                    alert.messageText = IFUtility.localizedString("Could not import skein")
                    alert.informativeText = loadError
                    alert.addButton(withTitle: IFUtility.localizedString("Cancel"))
                    alert.beginSheetModal(for: window) { returnCode in
                        // do nothing.
                    }
                }
            }
        }
    }

    @objc(exportExtensionWithWindow:)
    func exportExtension(with window: NSWindow) {
        if project.isExtensionProject {
            // Save the project, without user interaction.
            project.save(self)

            // Set up an open panel
            let panel = NSSavePanel()

            panel.accessoryView = nil
            panel.allowedContentTypes = IFUtility.contentTypes(forFilenameExtensions: ["i7x"])
            panel.canSelectHiddenExtension = true
            panel.prompt = IFUtility.localizedString("Export Extension (.i7x)")
            panel.treatsFilePackagesAsDirectories = false
            panel.directoryURL = project.fileURL?.deletingLastPathComponent()
            panel.nameFieldStringValue = ((project.fileURL?.lastPathComponent ?? "") as NSString).deletingPathExtension

            // Show it
            panel.beginSheetModal(for: window) { result in
                // Copy the file to the specified path
                if result == .OK, let url = panel.url {
                    do {
                        try self.project.exportExtension(to: url, hidingExtension: panel.isExtensionHidden)
                    } catch {
                        panel.close()
                        NSAlert(error: error).beginSheetModal(for: window)
                    }
                }
            }
        }
    }
}
