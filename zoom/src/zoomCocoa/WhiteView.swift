//
//  WhiteView.swift
//  Zoom
//
//  Created by C.W. Betts on 10/2/21.
//

import Cocoa

public class WhiteView: NSView {
	public override func draw(_ dirtyRect: NSRect) {
		let ourRect = self.bounds

		NSColor.textBackgroundColor.set()
		ourRect.fill()
	}
}
