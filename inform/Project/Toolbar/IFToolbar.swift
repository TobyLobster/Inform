//
//  IFToolbar.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation


class IFToolbar: NSToolbar {
    @objc static let ChangedVisibility = Notification.Name("IFToolbarChangedVisibility")

    func setVisible(shown:Bool) {
        super.isVisible = shown

        NotificationCenter.default.post(name: IFToolbar.ChangedVisibility, object: self)
    }
}
