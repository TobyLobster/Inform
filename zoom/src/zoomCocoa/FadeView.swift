//
//  FadeView.swift
//  Zoom
//
//  Created by C.W. Betts on 10/2/21.
//

import Cocoa

class FadeView: NSView {
	
	override func draw(_ dirtyRect: NSRect) {
		let grad = NSGradient(starting: NSColor.windowBackgroundColor.withAlphaComponent(0), ending: NSColor.textBackgroundColor)
		grad?.draw(in: bounds, angle: 270)
	}
	
	override var isOpaque: Bool {
		return false
	}
}
