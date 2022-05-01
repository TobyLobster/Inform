//
//  PreferenceController.swift
//  Inform
//
//  Created by C.W. Betts on 11/23/21.
//

import Cocoa

/// Preferences are different from settings (settings are per-project, preferences are global)
/// There's some overlap, though. In particular, installed extensions is global, but can be
/// controlled from an individual project's Settings as well as overall.
@objcMembers
final class PreferenceController : NSWindowController, NSWindowDelegate, NSToolbarDelegate {
	
	/// Contains the list of settings panes
	private var preferenceToolbar: NSToolbar?
	/// The settings panes themselves
	private var preferenceViews = [IFPreferencePane]()
	/// The toolbar items
	private var toolbarItems = [NSToolbarItem.Identifier: NSToolbarItem]()
	
	// Construction, etc
	/// The general preference controller
	@objc(sharedPreferenceController) public static let shared: PreferenceController = PreferenceController()
	
	init() {
		let mainScreenRect = NSScreen.main!.frame
		
		super.init(window: NSWindow(contentRect: NSRect(x: mainScreenRect.minX + 200, y: mainScreenRect.maxY - 400, width: 512, height: 300), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: true))
		
		// Set up window
		self.windowFrameAutosaveName = "PreferenceWindow";
		self.window?.delegate = self
		self.window?.title = IFUtility.localizedString("Inform Preferences")
		if #available(macOS 11.0, *) {
			self.window?.toolbarStyle = .preference
		}
	}
	
	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc private func preferencesWillClose(_ notification: NSNotification) {
		guard let windowAboutToClose = notification.object as? NSWindow,
			  window === windowAboutToClose else {
				  return
			  }
		// Save the position of the top left corner of window
		var topLeft = NSPoint()
		let rect = windowAboutToClose.frame
		topLeft.x = rect.minX
		topLeft.y = rect.maxY
		topLeft.y = windowAboutToClose.screen!.frame.size.height - topLeft.y
		IFPreferences.shared.preferencesTopLeftPosition = topLeft
		
		// Remove notifier
		NotificationCenter.default.removeObserver(self)
		
		// Remove any open color panel
		if NSColorPanel.sharedColorPanelExists {
			NSColorPanel.shared.close()
		}

		if NSFontPanel.sharedFontPanelExists {
			NSFontPanel.shared.close()
		}
	}
	
	public override func showWindow(_ sender: Any?) {
		// Set up the toolbar while showing the window
		if preferenceToolbar == nil {
			preferenceToolbar = NSToolbar(identifier: "PreferenceWindowToolbarMk2")

			preferenceToolbar!.allowsUserCustomization = false
			preferenceToolbar!.autosavesConfiguration = false

			preferenceToolbar!.delegate = self
			preferenceToolbar!.displayMode = .iconAndLabel
			self.window?.toolbar = preferenceToolbar
			preferenceToolbar!.isVisible = true

			`switch`(toPreferencePane: preferenceViews.first!.identifier)
		}

		// Set the window frame based on stored coordinates
		var topLeft = IFPreferences.shared!.preferencesTopLeftPosition
		topLeft.y = NSScreen.screens.first!.frame.size.height - topLeft.y
		var rect = window!.frame
		rect.origin.x = topLeft.x
		rect.origin.y = topLeft.y - rect.height
		
		window!.setFrame(rect, display: true)

		NotificationCenter.default.addObserver(self, selector: #selector(self.preferencesWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
		
		super.showWindow(sender)
	}
	
	// Adding new preference views
	/// Adds a new preference pane
	@objc(addPreferencePane:)
	public func add(_ newPane: IFPreferencePane) {
		// Add to the list of preferences view
		preferenceViews.append(newPane)
		
		// Add to the toolbar
		let newItem = NSToolbarItem(itemIdentifier: newPane.identifier!)
		
		newItem.action = #selector(self.switchPrefPane(_:))
		newItem.target = self
		newItem.image = newPane.toolbarImage
		newItem.label = newPane.preferenceName
		newItem.toolTip = newPane.tooltip
		
		toolbarItems[newPane.identifier!] = newItem;
		
	}
	
	public func removeAllPreferencePanes() {
		preferenceToolbar = nil
		preferenceViews.removeAll()
		toolbarItems.removeAll()
	}
	
	// MARK: Choosing a preference pane
	
	/// Switches to a specific preference pane
	public func `switch`(toPreferencePane paneIdentifier: NSToolbarItem.Identifier) {
		// Find the preference view that we're using
		var toolId: IFPreferencePane? = nil
		
		for possibleToolId in preferenceViews {
			if possibleToolId.identifier == paneIdentifier {
				toolId = possibleToolId
				break;
			}
		}
		
		guard let toolId = toolId,
			  let preferencePane = toolId.preferenceView,
			  window?.contentView !== preferencePane else {
				  return
			  }
		
		preferenceToolbar!.selectedItemIdentifier = paneIdentifier
		
		var currentFrame = window!.contentView!.frame
		let oldFrame = currentFrame
		var windowFrame = window!.frame
		
		currentFrame.origin.y    -= preferencePane.frame.size.height - currentFrame.size.height
		currentFrame.size.height  = preferencePane.frame.size.height
		
		// Grr, complicated, as OS X provides no way to work out toolbar proportions except in 10.3
		// FIXME: use these "new" methods
		windowFrame.origin.x    += currentFrame.origin.x - oldFrame.origin.x
		windowFrame.origin.y    += currentFrame.origin.y - oldFrame.origin.y
		windowFrame.size.width  += currentFrame.size.width - oldFrame.size.width
		windowFrame.size.height += currentFrame.size.height - oldFrame.size.height
		
		window?.contentView = NSView()
		window?.setFrame(windowFrame,
						 display: true,
						 animate: true)
		window?.contentView = preferencePane
	}
	
	// MARK: - Toolbar delegate
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return preferenceViews.map { toolId in
			return toolId.identifier
		}
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		var res = toolbarAllowedItemIdentifiers(toolbar)
		
		res.append(NSToolbarItem.Identifier.flexibleSpace)
		
		return res
	}
	
	func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return toolbarAllowedItemIdentifiers(toolbar)
	}
	
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		return toolbarItems[itemIdentifier]
	}
	
	// MARK: - Preference switching
	
	/// Retrieves a pane with a specific identifier
	public func preferencePane(_ paneIdentifier: NSToolbarItem.Identifier) -> IFPreferencePane? {
		for toolId in preferenceViews {
			if toolId.identifier == paneIdentifier {
				return toolId
			}
		}
		
		return nil
	}
	
	@objc private func switchPrefPane(_ sender: NSToolbarItem?) {
		if let sender = sender {
			`switch`(toPreferencePane: sender.itemIdentifier)
		}
	}
}
