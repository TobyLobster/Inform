//
//  IFSettingsPage.swift
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

import Cocoa

@objc @implementation extension IFSettingsPage {
    // Settings
    /// The settings controller
    @IBOutlet private final var settingsController: IFSettingsController?

    // MARK: - Initialisation

    init(projectController controller: IFProjectController) {
        super.init(nibName: "Settings",
                   projectController: controller)

        updateSettings()

        // A project read again, as by Revert To Saved, has new settings
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(projectSettingsReplaced(_:)),
                                               name: .IFProjectSettingsReplaced,
                                               object: nil)
    }

    @objc private final func projectSettingsReplaced(_ notification: Notification) {
        if (notification.object as AnyObject?) === parent?.document {
            updateSettings()
        }
    }

    // MARK: - Details about this view

    public override var title: String {
        return IFUtility.localizedString("Settings Page Title",
                                         default: "Settings")
    }

    // MARK: - Settings

    func updateSettings() {
        guard let parent else {
            return // Nothing to do
        }

        settingsController?.compilerSettings = (parent.document as? IFProject)?.settings
        settingsController?.updateAllSettings()
    }
}
