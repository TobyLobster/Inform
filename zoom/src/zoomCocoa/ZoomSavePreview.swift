//
//  ZoomSavePreview.swift
//  Zoom
//
//  Created by C.W. Betts on 9/24/21.
//

import Cocoa
import ZoomView
import ZoomView.ZoomUpperWindow

private let saveHighlightInactive = NSImage(named: "saveHighlightInactive")!
private let saveHighlightActive = NSImage(named: "saveHighlightActive")!
private let saveBackground = NSImage(named: "saveBackground")!

class SavePreview : NSView {
	@available(*, deprecated, renamed: "SavePreview.fileURL")
	var filename: String? {
		return fileURL?.path
	}
	private(set) var fileURL: URL?
	private var preview: ZoomUpperWindow?
	private var previewLines: [Any]?
	
	var isHighlighted: Bool = false {
		didSet {
			needsDisplay = true
		}
	}

	convenience init(preview prev: ZoomUpperWindow, with filename: URL) {
		self.init()
		preview = prev
		self.fileURL = filename
	}
	
	convenience init(previewStrings prev: [Any], with filename: URL) {
		self.init()
		previewLines = prev
		self.fileURL = filename
	}
	
	override var isFlipped: Bool {
		return true
	}
	
	override func mouseDown(with event: NSEvent) {
		
	}
	
	override func mouseUp(with event: NSEvent) {
		if let aSuper = superview as? SavePreviewView {
			aSuper.previewMouseUp(event, in: self)
		} else {
			isHighlighted = !isHighlighted
		}
	}
	
	@IBAction func deleteSavegame(_ sender: Any?) {
		// Display a confirmation dialog
		let alert = NSAlert()
		alert.messageText = NSLocalizedString("Are you sure?", comment: "Are you sure?")
		alert.informativeText = NSLocalizedString("Are you sure you want to delete this saved game?", comment: "Are you sure you want to delete this saved game?")
		let desButton = alert.addButton(withTitle: NSLocalizedString("Delete Game", value: "Delete", comment: "Delete"))
		if #available(macOS 11.0, *) {
			desButton.hasDestructiveAction = true
		}
		alert.addButton(withTitle: NSLocalizedString("Keep Game", value: "Keep", comment: "Keep"))
		alert.beginSheetModal(for: window!) { returnCode in
			guard returnCode == .alertFirstButtonReturn else {
				return
			}
			// Ensure that this is a genuine savegame
			var genuine = true
			var reason: String? = nil
			
			let saveURL = self.fileURL!.deletingLastPathComponent()

			if saveURL.pathExtension.lowercased() != "zoomsave" && saveURL.pathExtension.lowercased() != "glksave" {
				genuine = false
				reason = String(format: NSLocalizedString("File has the wrong extension (%@)", comment: "File has the wrong extension (%@)"), saveURL.pathExtension)
			}
			var isDir: ObjCBool = false
			if !urlIsAvailable(saveURL, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) {
				genuine = false
				reason = reason ?? NSLocalizedString("File does not exist", comment: "File does not exist")
			}
			if !isDir.boolValue {
				genuine = false
				reason = reason ?? NSLocalizedString("File is not a directory", comment: "File is not a directory")
			}
			
			let saveQut = saveURL.appendingPathComponent("save.qut")
			let zPreview = saveURL.appendingPathComponent("ZoomPreview.dat")
			let status = saveURL.appendingPathComponent("ZoomStatus.dat")
			
			if !urlIsAvailable(saveQut, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) || isDir.boolValue {
				genuine = false
				reason = reason ?? NSLocalizedString("Contents do not look like a saved game", comment: "Contents do not look like a saved game")
			}
			
			if !urlIsAvailable(zPreview, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) || isDir.boolValue {
				genuine = false
				reason = reason ?? NSLocalizedString("Contents do not look like a saved game", comment: "Contents do not look like a saved game")
			}
			
			if !urlIsAvailable(status, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil) || isDir.boolValue {
				genuine = false
				reason = reason ?? NSLocalizedString("Contents do not look like a saved game", comment: "Contents do not look like a saved game")
			}
			
			guard genuine else {
				let alert = NSAlert()
				alert.messageText = NSLocalizedString("Invalid save game", comment: "Invalid save game")
				alert.informativeText = String(format: NSLocalizedString("Invalid save game Info %@", comment: "Tell user that it couldn't load save game. %@ is the localized reason why."), reason!)
				alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
				alert.runModal()

				return
			}
			
			// Delete the game
			try? FileManager.default.removeItem(at: saveURL)
			// Force an update of the game window (bit of a hack, being lazy)
			NotificationCenter.default.post(name: ZoomStoryOrganiser.changedNotification, object: ZoomStoryOrganiser.shared)
		}
	}
	
	@IBAction func revealInFinder(_ sender: Any?) {
		let dir = fileURL!.deletingLastPathComponent().deletingLastPathComponent()
		var isDir: ObjCBool = false
		
		guard urlIsAvailable(dir, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil), isDir.boolValue else {
			return
		}
		
		NSWorkspace.shared.activateFileViewerSelecting([fileURL!.deletingLastPathComponent()])
	}
	
	override func draw(_ dirtyRect: NSRect) {
		let lineFont = NSFont.systemFont(ofSize: 9)
		let infoFont = NSFont.boldSystemFont(ofSize: 11)
		
		let ourBounds = self.bounds
		
		// Background
		let textColour: NSColor
		let backgroundImage: NSImage

		if isHighlighted {
			//if (saveHighlightActive) {
			backgroundImage = saveHighlightActive
			NSColor.clear.set()
			//} else {
			//	backgroundColour = [NSColor highlightColor];
			//	[[NSColor colorWithDeviceRed: .02 green: .39 blue: .80 alpha: 1.0] set];
			//}
			textColour = NSColor.white
		} else {
			//if (saveBackground) {
			backgroundImage = saveBackground
			//} else {
			//	backgroundColour = [NSColor whiteColor];
			//}
			NSColor(deviceRed: 0.76, green: 0.76, blue: 0.76, alpha: 1).set()
			textColour = NSColor.black
		}
		NSGraphicsContext.current?.patternPhase = self.convert(.zero, to: nil)
		
		backgroundImage.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
		NSBezierPath.defaultLineWidth = 1
		NSBezierPath.stroke(NSRect(x: ourBounds.origin.x+0.5, y: ourBounds.origin.y+0.5,
								   width: ourBounds.width-1.0, height: ourBounds.height-1.0))
		
		// Preview lines (from the top)
		let previewStyle: [NSAttributedString.Key: Any] = [
			.font: lineFont,
			.foregroundColor: textColour,
		]
		
		var yPos: CGFloat = 4
		var lines = 0
		var upperLines: [Any]
		if let preview = preview {
			upperLines = preview.lines
		} else if let previewLines = previewLines {
			upperLines = previewLines
		} else {
			upperLines = []
		}
		
		for thisLine in upperLines {
			let lineString: String
			if let theLine = thisLine as? String {
				lineString = theLine
			} else if let theLine = thisLine as? NSAttributedString {
				lineString = theLine.string
			} else {
				lineString = (thisLine as AnyObject).string() ?? ""
			}
			// TODO: Strip any multiple spaces out of this line

			// Draw this string
			let stringSize = lineString.size(withAttributes: previewStyle)
			
			lineString.draw(in: NSRect(x: 4, y: yPos,
									   width: ourBounds.width - 8,
									   height: stringSize.height),
							withAttributes: previewStyle)
			yPos += stringSize.height
			
			// Finish up
			lines += 1
			if lines > 2 {
				break
			}
		}
		
		// Draw the filename
		let infoStyle: [NSAttributedString.Key: Any] = [
			.font: infoFont,
			.foregroundColor: textColour,
		]
		
		let displayName = fileURL!.deletingLastPathComponent().deletingPathExtension().lastPathComponent
		
		let infoSize = displayName.size(withAttributes: infoStyle)
		var infoRect = ourBounds
		
		infoRect.origin.x = 4
		infoRect.origin.y = ourBounds.height - 4 - infoSize.height
		infoRect.size.width -= 8
		
		displayName.draw(in: infoRect, withAttributes: infoStyle)

		// Draw the date (if there's room)
		infoRect.size.width -= infoSize.width + 4
		infoRect.origin.x += infoSize.width + 4
		
		if let res = try? fileURL!.resourceValues(forKeys: [.contentModificationDateKey]), let fileDate = res.contentModificationDate {
			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			formatter.timeStyle = .short
			formatter.formattingContext = .standalone
			
			let dateString = formatter.string(from: fileDate)
			let dateSize = dateString.size(withAttributes: infoStyle)
			
			if dateSize.width <= infoRect.size.width {
				infoRect.origin.x = (infoRect.origin.x + infoRect.size.width) - dateSize.width
				infoRect.size.width = dateSize.width
				
				dateString.draw(in: infoRect, withAttributes: infoStyle)
			}
		}
	}
}
