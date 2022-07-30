//
//  AuthorPreferences.swift
//  Inform
//
//  Created by C.W. Betts on 11/23/21.
//

import Cocoa

final class AuthorPreferences : IFPreferencePane {
	/// The preferred name for new Natural Inform games
	@IBOutlet weak var newGameName: NSTextField?
	
	override init!() {
		super.init(nibName: "AuthorPreferences")
		
		reflectCurrentPreferences()
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.reflectCurrentPreferences),
											   name: .IFPreferencesAuthorDidChange,
											   object: IFPreferences.shared)
	}
	
	// MARK: Setting ourselves up
	
	@IBAction func setPreference(_ sender: AnyObject?) {
		let prefs = IFPreferences.shared!
		
		if sender === newGameName {
			prefs.freshGameAuthorName = newGameName?.stringValue
		}
	}
	
	@objc func reflectCurrentPreferences() {
		let prefs = IFPreferences.shared!
		
		newGameName?.stringValue = (prefs.freshGameAuthorName)!
	}
	
	// MARK: PreferencePane overrides
	
	override var preferenceName: String {
		return "Author"
	}
	
	override var toolbarImage: NSImage! {
		return Bundle(for: type(of: self)).image(forResource: NSImage.Name("App/person"))!;
	}
	
	override var tooltip: String! {
		return IFUtility.localizedString("Author preferences tooltip")
	}
}
