//
//  ZoomSavePreviewView.swift
//  Zoom
//
//  Created by C.W. Betts on 9/24/21.
//

import Cocoa
import ZoomView.ZoomUpperWindow
import ZoomPlugIns.ZoomStory

@objcMembers
class SavePreviewView: NSView {
	private var upperWindowViews = [SavePreview]()
	private var selected: Int? = nil
	private(set) var saveGamesAvailable: Bool = false

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		autoresizesSubviews = true
		autoresizingMask = .width
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		autoresizesSubviews = true
		autoresizingMask = .width
	}
	
	override func draw(_ dirtyRect: NSRect) {
		// do nothing
	}
	
	func setDirectoryToUse(_ directory: String?) {
		// Get rid of our old views
		for view in upperWindowViews {
			view.removeFromSuperview()
		}
		upperWindowViews.removeAll()
		
		saveGamesAvailable = false
		selected = nil
		guard let directory = directory, FileManager.default.fileExists(atPath: directory) else {
			var ourFrame = self.frame
			ourFrame.size.height = 2
			self.frame = ourFrame
			needsDisplay = true
			return
		}
		// Get our frame size
		var ourFrame = self.frame
		ourFrame.size.height = 0
		
		// Load all the zoomSave files from the given directory
		let url = URL(fileURLWithPath: directory)
		guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) else {
			return
		}

		for file in contents {
			switch file.pathExtension.lowercased() {
			case "zoomsave":
				let previewURL = file.appendingPathComponent("ZoomPreview.dat")
				
				var isDir: ObjCBool = false
				guard urlIsAvailable(previewURL, isDirectory: &isDir, isPackage: nil, isReadable: nil, error: nil), !isDir.boolValue else {
					continue
				}
				
				guard let preData = try? Data(contentsOf: previewURL) else {
					continue
				}
				var preVal: Any? = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ZoomUpperWindow.self, from: preData)
				if preVal == nil {
					preVal = NSUnarchiver.unarchiveObject(with: preData)
				}
				
				guard let win = preVal as? ZoomUpperWindow else {
					continue
				}
				
				let preview = SavePreview(preview: win, with: previewURL)
				preview.autoresizingMask = .width
				preview.menu = self.menu
				addSubview(preview)
				upperWindowViews.append(preview)
				
				saveGamesAvailable = true
				
			case "glksave":
				let propertiesURL = file.appendingPathComponent("Info.plist")
				guard (try? propertiesURL.checkResourceIsReachable()) ?? false else {
					continue
				}
				
				guard let dat = try? Data(contentsOf: propertiesURL),
					  let previewProperties = try? PropertyListSerialization.propertyList(from: dat, options: [], format: nil) as? [String: Any] else {
					continue
				}
				
				guard let strID = previewProperties["ZoomGlkGameId"] as? String else {
					continue
				}
				
				let storyId = ZoomStoryID(idString: strID)
				let previewLinesURL = file.appendingPathComponent("Preview.plist")
				let previewLines: [Any]
				if (try? previewLinesURL.checkResourceIsReachable()) ?? false,
				   let dat2 = try? Data(contentsOf: previewLinesURL),
				   let previewLines2 = try? PropertyListSerialization.propertyList(from: dat2, options: [], format: nil) as? [Any] {
					previewLines = previewLines2
				} else {
					// Use some defaults if no lines are supplied
					if let story = (NSApp.delegate as! ZoomAppDelegate).findStory(storyId) {
						previewLines = ["Saved story from '\(story.title!)'"]
					} else {
						previewLines = ["Saved story"]
					}
				}
				
				let preview = SavePreview(previewStrings: previewLines, with: propertiesURL)
				preview.autoresizingMask = .width
				preview.menu = menu
				addSubview(preview)
				upperWindowViews.append(preview)
				
				saveGamesAvailable = true

			default:
				break
			}
		}
		
		// Arrange the views, resize ourselves
		var size: CGFloat = 2
		let bounds = self.bounds
		
		for view in upperWindowViews {
			view.frame = NSRect(x: 0, y: size, width: bounds.size.width, height: 48)
			size += 49
		}
		
		var frame = self.frame
		frame.size.height = size
		
		setFrameSize(frame.size)
		needsDisplay = true
	}
	
	@available(*, deprecated, renamed: "SavePreviewView.selectedSaveGameURL")
	var selectedSaveGame: String? {
		return selectedSaveGameURL?.path
	}
	
	var selectedSaveGameURL: URL? {
		if let selVal = selected {
			return upperWindowViews[selVal].fileURL
		} else {
			return nil
		}
	}

	
	func previewMouseUp(_ evt: NSEvent, in view: SavePreview) {
		guard let clicked = upperWindowViews.firstIndex(of: view) else {
			NSLog("BUG: save preview not found")
			return
		}
		
		if evt.clickCount == 1 {
			// Select a new view
			if let selected = selected {
				upperWindowViews[selected].isHighlighted = false
			}
			
			view.isHighlighted = true
			selected = clicked
		} else if evt.clickCount == 2 {
			// Launch this game
			let fileURL = view.fileURL!
			let directory = fileURL.deletingLastPathComponent()
			if directory.pathExtension.lowercased() == "glksave" {
				// Pass off to the app delegate
				_=NSApp.delegate?.application?(NSApp, openFile: fileURL.path)
			} else {
				NSDocumentController.shared.openDocument(withContentsOf: directory, display: true) { documen, documentWasAlreadyOpen, error in
					// do nothing
				}
			}
		}
	}
}
