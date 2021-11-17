//
//  ZoomPreferences.swift
//  ZoomView
//
//  Created by C.W. Betts on 11/13/21.
//

import Cocoa

@objc public enum GlulxInterpreter : Int {
	@objc(GlulxGit) case git = 0
	@objc(GlulxGlulxe) case glulxe = 1
}

extension NSNotification.Name {
	public static let ZoomPreferencesHaveChanged: NSNotification.Name = NSNotification.Name(rawValue: "ZoomPreferencesHaveChangedNotification")
}

// MARK: Preference keys

private let displayWarningsKey = "DisplayWarnings"
private let fatalWarningsKey = "FatalWarnings"
private let speakGameTextKey = "SpeakGameText"
private let scrollbackLengthKey = "ScrollbackLength"
private let confirmGameCloseKey = "ConfirmGameClose"
private let keepGamesOrganisedKey = "KeepGamesOrganised"
private let autosaveGamesKey = "autosaveGames"

private let gameTitleKey = "GameTitle"
private let interpreterKey = "Interpreter"
private let glulxInterpreterKey = "GlulxInterpreter"
private let revisionKey = "Revision"

private let fontsKey = "Fonts"
private let coloursKey = "Colours"
private let textMarginKey = "TextMargin"
private let useScreenFontsKey = "UseScreenFonts"
private let useHyphenationKey = "UseHyphenation"
private let useKerningKey = "UseKerning"
private let useLigaturesKey = "UseLigatures"

private let organiserDirectoryKey = "organiserDirectory"

private let foregroundColourKey = "ForegroundColour"
private let backgroundColourKey = "BackgroundColour"
private let showBordersKey = "ShowBorders"
private let showGlkBordersKey = "ShowGlkBorders"
private let showCoverPictureKey = "ShowCoverPicture"

private let DefaultFonts: [NSFont] = {
	let defaultFontName = "Gill Sans"
	let fixedFontName = "Courier"
	let mgr = NSFontManager.shared
	
	var defaultFonts = [NSFont]()
	
	var variableFont = mgr.font(withFamily: defaultFontName, traits: .unboldFontMask, weight: 5, size: 12)
	var fixedFont = mgr.font(withFamily: fixedFontName, traits: .unboldFontMask, weight: 5, size: 12)
	
	if (variableFont == nil) {
		variableFont = NSFont.systemFont(ofSize: 12)
	}
	if (fixedFont == nil) {
		fixedFont = NSFont.userFixedPitchFont(ofSize: 12)
	}
	
	for x2 in ZFontStyle.RawValue(0) ..< 16 {
		var thisFont = variableFont!
		let x = ZFontStyle(rawValue: x2)
		if x.contains(.fixed) {
			thisFont = fixedFont!
		}
		if x.contains(.bold) {
			thisFont = mgr.convert(thisFont,
								   toHaveTrait: .boldFontMask)
		}
		
		if x.contains(.underline) {
			thisFont = mgr.convert(thisFont,
								   toHaveTrait: .italicFontMask)
		}
		
		if x.contains(.fixed) {
			thisFont = mgr.convert(thisFont,
								   toHaveTrait: .fixedPitchFontMask)
		}
		
		defaultFonts.append(thisFont)
	}
	return defaultFonts
}()

private let DefaultColours = [
	NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
	NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
	NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
	NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1),
	NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
	NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1),
	NSColor(srgbRed: 0, green: 1, blue: 1, alpha: 1),
	NSColor(srgbRed: 1, green: 1, blue: 0.8, alpha: 1),

	NSColor(srgbRed: 0.73, green: 0.73, blue: 0.73, alpha: 1),
	NSColor(srgbRed: 0.53, green: 0.53, blue: 0.53, alpha: 1),
	NSColor(srgbRed: 0.26, green: 0.26, blue: 0.26, alpha: 1)
]

private let firstRun: () = {
	let defaultPrefs = ZoomPreferences(defaultPreferences: ())
	let appDefaults: [String: Any] = ["ZoomGlobalPreferences": defaultPrefs.dictionary]
	
	UserDefaults.standard.register(defaults: appDefaults)
}()

private func compareValues(_ a: [String: Any], _ b: [String: Any], usingKey key: String) -> Bool {
	let aVal = a[key] as? NSObject
	let bVal = b[key] as? NSObject
	if let aVal = aVal {
		return aVal.isEqual(bVal)
	}
	return false
}

@objcMembers
public class ZoomPreferences : NSObject, NSSecureCoding, NSCopying {
	public static var preferencesHaveChangedNotification: NSNotification.Name {
		return .ZoomPreferencesHaveChanged
	}
	
	private var prefs = [String: Any]()
	private let prefLock = NSLock()
	
	// init is the designated initialiser for this class
	public override init() {
		super.init()
	}
 
	@objc(globalPreferences)
	public static let global: ZoomPreferences = {
		_=firstRun
		var toRet: ZoomPreferences
		if let globalDict = UserDefaults.standard.dictionary(forKey: "ZoomGlobalPreferences") {
			toRet = ZoomPreferences(dictionary: globalDict)
		} else {
			toRet = ZoomPreferences(defaultPreferences: ())
		}
		
		// Must contain valid fonts and colours
		if toRet.prefs[fontsKey] == nil || toRet.prefs[coloursKey] == nil {
			NSLog("Missing element in global preferences: replacing")
			toRet = ZoomPreferences(defaultPreferences: ())
		}
		
		return toRet
	}()

	public convenience init(defaultPreferences: ()) {
		self.init()
		// Defaults
		prefs[displayWarningsKey] = false
		prefs[fatalWarningsKey] = false
		prefs[speakGameTextKey] = false
		
		prefs[gameTitleKey] = "%s (%i.%.6s.%04x)"
		prefs[interpreterKey] = 3
		prefs[revisionKey] = UInt8(0x5A)
		prefs[glulxInterpreterKey] = GlulxInterpreter.git.rawValue
		
		prefs[fontsKey] = DefaultFonts
		prefs[coloursKey] = DefaultColours
		
		prefs[foregroundColourKey] = 0
		prefs[backgroundColourKey] = 7
		prefs[showBordersKey] = true
		prefs[showGlkBordersKey] = true
	}

 
	public init(dictionary preferences: [String : Any]) {
		_=firstRun
		prefs = preferences
		
		if let fts = prefs[fontsKey] as? Data {
			var tmp = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSFont.self], from: fts)
			if tmp == nil {
				tmp = NSUnarchiver.unarchiveObject(with: fts)
			}
			if let tmp = tmp as? [NSFont] {
				prefs[fontsKey] = tmp
			} else {
				prefs.removeValue(forKey: fontsKey)
			}
		}
		
		if let cols = prefs[coloursKey] as? Data {
			var tmp = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSColor.self], from: cols)
			if tmp == nil {
				tmp = NSUnarchiver.unarchiveObject(with: cols)
			}
			if let tmp = tmp as? [NSColor] {
				prefs[coloursKey] = tmp
			} else {
				prefs.removeValue(forKey: coloursKey)
			}
		}
		
		// Verify that things are intact
		if let newFonts = prefs[fontsKey] as? [NSFont], newFonts.count == 16 {
			
		} else {
			NSLog("Unable to decode font block completely: using defaults")
			prefs[fontsKey] = DefaultFonts
		}
		
		if let newColors = prefs[coloursKey] as? [NSColor], newColors.count == 11 {
			
		} else {
			NSLog("Unable to decode colour block completely: using defaults")
			prefs[coloursKey] = DefaultColours
		}
	}
 
	// Getting preferences
 
	open class var defaultOrganiserDirectory: String {
		_=firstRun
		let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true);
		
		let res = (docDir.first! as NSString).appendingPathComponent("Interactive Fiction")
		
		return res
	}
	
	// MARK: - Warnings and game text prefs
	
	open var displayWarnings: Bool {
		get {
			prefLock.lock()
			let result = prefs[displayWarningsKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[displayWarningsKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var fatalWarnings: Bool {
		get {
			prefLock.lock()
			let result = prefs[fatalWarningsKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[fatalWarningsKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var speakGameText: Bool {
		get {
			prefLock.lock()
			let result = prefs[speakGameTextKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[speakGameTextKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var confirmGameClose: Bool {
		get {
			prefLock.lock()
			let result = prefs[confirmGameCloseKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[confirmGameCloseKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	/// 0-100
	open var scrollbackLength: CGFloat {
		get {
			prefLock.lock()
			let result = prefs[scrollbackLengthKey] as? CGFloat
			prefLock.unlock()
			
			return result ?? 0
		}
		set {
			prefs[scrollbackLengthKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	
	// MARK: - Interpreter preferences
	
	open var gameTitle: String? {
		get {
			prefLock.lock()
			let result = prefs[gameTitleKey] as? String
			prefLock.unlock()
			
			return result
		}
		set {
			if let newValue = newValue {
				prefs[gameTitleKey] = newValue
			} else {
				prefs.removeValue(forKey: gameTitleKey)
			}
			preferencesHaveChanged()
		}
	}
	
	open var interpreter: Int32 {
		get {
			prefLock.lock()
			let result = prefs[interpreterKey] as? Int32
			prefLock.unlock()
			
			return result ?? 0
		}
		set {
			prefs[interpreterKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var glulxInterpreter: GlulxInterpreter {
		get {
			prefLock.lock()
			let result = prefs[glulxInterpreterKey] as? Int
			prefLock.unlock()
			
			if let result = result, let result2 = GlulxInterpreter(rawValue: result) {
				return result2
			}
			return .git
		}
		set {
			prefs[glulxInterpreterKey] = newValue.rawValue
			preferencesHaveChanged()
		}
	}
	
	open var revision: UInt8 {
		get {
			prefLock.lock()
			let result = prefs[revisionKey] as? UInt8
			prefLock.unlock()
			
			return result ?? 0
		}
		set {
			prefs[revisionKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	// MARK: -
	
	public override func isEqual(_ object: Any?) -> Bool {
		if let object = object as? ZoomPreferences {
			if !compareValues(prefs, object.prefs, usingKey: displayWarningsKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: fatalWarningsKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: speakGameTextKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: gameTitleKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: interpreterKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: revisionKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: glulxInterpreterKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: displayWarningsKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: fontsKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: coloursKey) {
				return false
			}
			
			
			if !compareValues(prefs, object.prefs, usingKey: foregroundColourKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: backgroundColourKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: showBordersKey) {
				return false
			}
			
			if !compareValues(prefs, object.prefs, usingKey: showGlkBordersKey) {
				return false
			}
			
			return true
		}
		return false
	}
	
	// MARK: - Typographical preferences
	
	/// 16 fonts
	open var fonts: [NSFont] {
		get {
			prefLock.lock()
			let result = (prefs[fontsKey] as? [NSFont]) ?? DefaultFonts
			prefLock.unlock()
			
			return result
		}
		set {
			prefs[fontsKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	/// 13 colours
	open var colours: [NSColor]? {
		get {
			prefLock.lock()
			let result = prefs[coloursKey] as? [NSColor]
			prefLock.unlock()
			
			return result
		}
		set {
			if let newValue = newValue {
				prefs[coloursKey] = newValue
			} else {
				prefs.removeValue(forKey: coloursKey)
			}
			preferencesHaveChanged()
		}
	}
	
	open var proportionalFontFamily: String? {
		get {
			// Font 0 forms the prototype for this
			let prototypeFont = fonts[0]
			
			return prototypeFont.familyName
		}
		set {
			if let newValue = newValue {
				setFontRange(0..<4, toFamily: newValue)
			}
		}
	}
	
	open var fixedFontFamily: String? {
		get {
			// Font 4 forms the prototype for this
			let prototypeFont = fonts[4]
			
			return prototypeFont.familyName
		}
		set {
			if let newValue = newValue {
				setFontRange(4..<8, toFamily: newValue)
			}
		}
	}
	
	open var symbolicFontFamily: String? {
		get {
			// Font 8 forms the prototype for this
			let prototypeFont = fonts[8]
			
			return prototypeFont.familyName
		}
		set {
			if let newValue = newValue {
				setFontRange(8..<16, toFamily: newValue)
			}
		}
	}
	
	private func setFontRange(_ fontRange: Range<Int>, toFamily newFamilyName: String) {
		let size = fontSize
		
		var newFonts = fonts
		let mgr = NSFontManager.shared
		
		for x in fontRange {
			// Get the traits for this font
			var traits = NSFontTraitMask()
			
			if x & 1 != 0 {
				traits.insert(.boldFontMask)
			}
			
			if x & 2 != 0 {
				traits.insert(.italicFontMask)
			}

			if x & 4 != 0 {
				traits.insert(.fixedPitchFontMask)
			}

			// Get a suitable font
			var newFont = mgr.font(withFamily: newFamilyName, traits: traits, weight: 5, size: size)
			if newFont == nil || newFont!.familyName?.caseInsensitiveCompare(newFamilyName) != .orderedSame {
				// Retry with simpler conditions if we fail to get a font for some reason
				newFont = mgr.font(withFamily: newFamilyName, traits: (x & 4) != 0 ? .fixedPitchFontMask : [], weight: 5, size: size)
			}
			if let newFont = newFont {
				newFonts[x] = newFont
			}
		}
		
		self.fonts = newFonts
	}
	
	open var fontSize: CGFloat {
		get {
			// Font 0 forms the prototype for this
			let prototypeFont = fonts[0]
			
			return prototypeFont.pointSize
		}
		set {
			let fonts = fonts
			let mgr = NSFontManager.shared
			let newFonts = fonts.map { font in
				mgr.convert(font, toSize: newValue)
			}
			self.fonts = newFonts
		}
	}
	
	
	open var textMargin: CGFloat {
		get {
			prefLock.lock()
			let result = (prefs[textMarginKey] as? CGFloat) ?? 10
			prefLock.unlock()
			
			return result
		}
		set {
			prefs[textMarginKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var useScreenFonts: Bool {
		get {
			prefLock.lock()
			let result = prefs[useScreenFontsKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[useScreenFontsKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var useHyphenation: Bool {
		get {
			prefLock.lock()
			let result = prefs[useHyphenationKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[useHyphenationKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	
	open var useKerning: Bool {
		get {
			prefLock.lock()
			let result = prefs[useKerningKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[useKerningKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var useLigatures: Bool {
		get {
			prefLock.lock()
			let result = prefs[useLigaturesKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[useLigaturesKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	// MARK: - Organiser preferences
	
	open var organiserDirectory: String! {
		get {
			prefLock.lock()
			var result = prefs[useScreenFontsKey] as? String
			if result == nil {
				result = ZoomPreferences.defaultOrganiserDirectory
			}
			prefLock.unlock()
			
			return result!
		}
		set {
			if let newValue = newValue {
				prefs[useScreenFontsKey] = newValue
			} else {
				prefs.removeValue(forKey: useScreenFontsKey)
			}
			preferencesHaveChanged()
		}
	}
	
	open var keepGamesOrganised: Bool {
		get {
			prefLock.lock()
			let result = prefs[keepGamesOrganisedKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[keepGamesOrganisedKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var autosaveGames: Bool {
		get {
			prefLock.lock()
			let result = prefs[autosaveGamesKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[autosaveGamesKey] = newValue
			preferencesHaveChanged()
		}
	}

 
	// MARK: - Display preferences
	open var foregroundColour: Int32 {
		get {
			prefLock.lock()
			let result = prefs[foregroundColourKey] as? Int32
			prefLock.unlock()
			
			return result ?? 0
		}
		set {
			prefs[foregroundColourKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var backgroundColour: Int32 {
		get {
			prefLock.lock()
			let result = prefs[backgroundColourKey] as? Int32
			prefLock.unlock()
			
			return result ?? 0
		}
		set {
			prefs[backgroundColourKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var showBorders: Bool {
		get {
			prefLock.lock()
			let result = prefs[showBordersKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[showBordersKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var showGlkBorders: Bool {
		get {
			prefLock.lock()
			let result = prefs[showGlkBordersKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[showGlkBordersKey] = newValue
			preferencesHaveChanged()
		}
	}
	
	open var showCoverPicture: Bool {
		get {
			prefLock.lock()
			let result = prefs[showCoverPictureKey] as? Bool
			prefLock.unlock()
			
			return result ?? false
		}
		set {
			prefs[showCoverPictureKey] = newValue
			preferencesHaveChanged()
		}
	}

 
	/// The dictionary
	open var dictionary: [String : Any] {
		// Fonts and colours need encoding
		var newDict = prefs
		if let fts = newDict[fontsKey], let encFonts = try? NSKeyedArchiver.archivedData(withRootObject: fts, requiringSecureCoding: true) {
			newDict[fontsKey] = encFonts
		} else {
			newDict.removeValue(forKey: fontsKey)
		}
		
		if let cols = newDict[coloursKey], let encCols = try? NSKeyedArchiver.archivedData(withRootObject: cols, requiringSecureCoding: true) {
			newDict[coloursKey] = encCols
		} else {
			newDict.removeValue(forKey: coloursKey)
		}
		
		
		return newDict
	}

	/// Notifications
	open func preferencesHaveChanged() {
		NotificationCenter.default.post(name: .ZoomPreferencesHaveChanged, object: self)
		
		if self === ZoomPreferences.global {
			UserDefaults.standard.set(dictionary, forKey: "ZoomGlobalPreferences")
		}
	}
	
	// MARK: - NSCoding
	
	required public init?(coder: NSCoder) {
		if coder.allowsKeyedCoding {
			if let newPrefs = coder.decodeObject(of: [NSDictionary.self, NSString.self, NSColor.self, NSFont.self, NSArray.self, NSNumber.self], forKey: "prefs") as? [String: Any] {
				prefs = newPrefs
			}
		} else {
			if let newPrefs = coder.decodeObject() as? [String: Any] {
				prefs = newPrefs
			}
		}
	}

	public func encode(with coder: NSCoder) {
		if coder.allowsKeyedCoding {
			coder.encode(prefs, forKey: "prefs")
		} else {
			coder.encode(prefs)
		}
	}
	
	public class var supportsSecureCoding: Bool {
		return true
	}

	// MARK: - NSCopying
	
	open func copy(with zone: NSZone? = nil) -> Any {
		let ourDict = dictionary
		return ZoomPreferences(dictionary: ourDict)
	}
}
