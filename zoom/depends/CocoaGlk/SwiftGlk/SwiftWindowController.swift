//
//  SwiftWindowController.swift
//  SwiftGlk
//
//  Created by C.W. Betts on 3/5/18.
//

import Cocoa
import GlkView.GlkView

class SwiftWindowController: NSWindowController, GlkViewDelegate {
	/// The view in which the actual action takes place
	@IBOutlet weak var glkView: GlkView!
	
	/// The statusbar text
	@IBOutlet weak var status: NSTextField!
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("CocoaGlk"))
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		
		self.windowFrameAutosaveName = NSWindow.FrameAutosaveName("SwiftGlkWindow")
		
		// Set the status
		status.stringValue = NSLocalizedString("Waiting for game...", comment: "Waiting for game...")
		
		// We're the view delegate
		glkView.delegate = self
	}
	
	// = GlkView delegate methods =
	
	func taskHasStarted() {
		showStatusText("Running...")
	}
	
	func taskHasFinished() {
		showStatusText("Finished")
	}

	func showStatusText(_ status: String) {
		self.status.stringValue = status
	}
}
