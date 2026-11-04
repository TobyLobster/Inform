//
//  IFClickThroughScrollView.swift
//  Inform
//
//  Created by Toby Nelson on 28/09/2023.
//

import Foundation

class IFClickThroughScrollView: NSScrollView {

    override func mouseDown(with event: NSEvent) {
        // Pass the event through to the contained view
        self.documentView?.mouseDown(with: event)

        // Continue as normal
        super.mouseDown(with: event)
    }
}
