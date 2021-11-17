//
//  ClearView.swift
//  ZoomPlugIns
//
//  Created by C.W. Betts on 10/2/21.
//

import Cocoa

public class ClearView: NSView {
	public override func draw(_ dirtyRect: NSRect) {
		let ourRect = self.bounds

		NSColor.clear.set()
		ourRect.fill()
    }
    
	public override var isOpaque: Bool {
		return false
	}
}
