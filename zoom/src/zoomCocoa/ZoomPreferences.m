//
//  ZoomPreferences.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomPreferences.h"


@implementation ZoomPreferences

// == Preference keys ==

NSString* ZoomPreferencesHaveChangedNotification = @"ZoomPreferencesHaveChangedNotification";

static NSString* displayWarnings	= @"DisplayWarnings";
static NSString* fatalWarnings		= @"FatalWarnings";
static NSString* speakGameText		= @"SpeakGameText";
static NSString* scrollbackLength	= @"ScrollbackLength";
static NSString* confirmGameClose   = @"ConfirmGameClose";
static NSString* keepGamesOrganised = @"KeepGamesOrganised";
static NSString* autosaveGames		= @"autosaveGames";

static NSString* gameTitle			= @"GameTitle";
static NSString* interpreter		= @"Interpreter";
static NSString* glulxInterpreter	= @"GlulxInterpreter";
static NSString* revision			= @"Revision";

static NSString* fonts				= @"Fonts";
static NSString* colours			= @"Colours";
static NSString* textMargin			= @"TextMargin";
static NSString* useScreenFonts		= @"UseScreenFonts";
static NSString* useHyphenation		= @"UseHyphenation";
static NSString* useKerning			= @"UseKerning";
static NSString* useLigatures		= @"UseLigatures";

static NSString* organiserDirectory = @"organiserDirectory";

static NSString* foregroundColour   = @"ForegroundColour";
static NSString* backgroundColour   = @"BackgroundColour";
static NSString* showBorders		= @"ShowBorders";
static NSString* showGlkBorders		= @"ShowGlkBorders";
static NSString* showCoverPicture   = @"ShowCoverPicture";

// == Global preferences ==

static ZoomPreferences* globalPreferences = nil;
static NSLock*          globalLock = nil;

+ (NSString*) defaultOrganiserDirectory {
	NSArray* docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	
	NSString* res = [docDir[0] stringByAppendingPathComponent: @"Interactive Fiction"];
	
	return res;
}

+ (void)initialize {
	NSAutoreleasePool* apool = [[NSAutoreleasePool alloc] init];
	
    NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
	ZoomPreferences* defaultPrefs = [[[self class] alloc] initWithDefaultPreferences];
    NSDictionary *appDefaults = @{@"ZoomGlobalPreferences": [defaultPrefs dictionary]};
	
	[defaultPrefs release];
	
    [defaults registerDefaults: appDefaults];
	
	globalLock = [[NSLock alloc] init];
	
	[apool release];
}

+ (ZoomPreferences*) globalPreferences {
	[globalLock lock];
	
	if (globalPreferences == nil) {
		NSDictionary* globalDict = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomGlobalPreferences"];
		
		if (globalDict== nil) 
			globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
		else
			globalPreferences = [[ZoomPreferences alloc] initWithDictionary: globalDict];
		
		// Must contain valid fonts and colours
		if ([globalPreferences fonts] == nil || [globalPreferences colours] == nil) {
			NSLog(@"Missing element in global preferences: replacing");
			[globalPreferences release];
			globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
		}
	}
	
	[globalLock unlock];
	
	return globalPreferences;
}

// == Initialisation ==

- (instancetype) init {
	self = [super init];
	
	if (self) {
		prefLock = [[NSLock alloc] init];
		prefs = [[NSMutableDictionary alloc] init];		
	}
	
	return self;
}

static NSArray* DefaultFonts(void) {
	NSString* defaultFontName = @"Gill Sans";
	NSString* fixedFontName = @"Courier";
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSMutableArray* defaultFonts = [[NSMutableArray alloc] init];
	
	NSFont* variableFont = [mgr fontWithFamily: defaultFontName
										traits: NSUnboldFontMask
										weight: 5
										  size: 12];
	NSFont* fixedFont = [mgr fontWithFamily: fixedFontName
									 traits: NSUnboldFontMask
									 weight: 5
									   size: 12];
	
	if (variableFont == nil) variableFont = [NSFont systemFontOfSize: 12];
	if (fixedFont == nil) fixedFont = [NSFont userFixedPitchFontOfSize: 12];
	
	int x;
	for (x=0; x<16; x++) {
		NSFont* thisFont = variableFont;
		if ((x&4)) thisFont = fixedFont;
		
		if ((x&1)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSBoldFontMask];
		if ((x&2)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSItalicFontMask];
		if ((x&4)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSFixedPitchFontMask];
		
		[defaultFonts addObject: thisFont];
	}
	
	return [defaultFonts autorelease];
}

static NSArray* DefaultColours(void) {
	return @[[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 0 blue: 1 alpha: 1],
		[NSColor colorWithDeviceRed: 0 green: 1 blue: 1 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 1 blue: .8 alpha: 1],
		
		[NSColor colorWithDeviceRed: .73 green: .73 blue: .73 alpha: 1],
		[NSColor colorWithDeviceRed: .53 green: .53 blue: .53 alpha: 1],
		[NSColor colorWithDeviceRed: .26 green: .26 blue: .26 alpha: 1]];
}

- (instancetype) initWithDefaultPreferences {
	self = [self init];
	
	if (self) {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		
		// Defaults
		prefs[displayWarnings] = @NO;
		prefs[fatalWarnings] = @NO;
		prefs[speakGameText] = @NO;
		
		prefs[gameTitle] = @"%s (%i.%.6s.%04x)";
		prefs[interpreter] = @3;
		prefs[revision] = @('Z');
		prefs[glulxInterpreter] = @(GlulxGit);
		
		prefs[fonts] = DefaultFonts();
		prefs[colours] = DefaultColours();
		
		prefs[foregroundColour] = @0;
		prefs[backgroundColour] = @7;
		prefs[showBorders] = @YES;
		prefs[showGlkBorders] = @YES;
		
		[pool release];
	}
	
	return self;
}

- (instancetype) initWithDictionary: (NSDictionary*) dict {
	self = [super init];
	
	if (self) {
		prefLock = [[NSLock alloc] init];
		prefs = [dict mutableCopy];
		
		// Fonts and colours will be archived if they exist
		NSData* fts = prefs[fonts];
		NSData* cols = prefs[colours];

		if ([fts isKindOfClass: [NSData class]]) {
			prefs[fonts] = [NSUnarchiver unarchiveObjectWithData: fts];
		}
		
		if ([cols isKindOfClass: [NSData class]]) {
			prefs[colours] = [NSUnarchiver unarchiveObjectWithData: cols];
		}
		
		// Verify that things are intact
		NSArray* newFonts = prefs[fonts];
		NSArray* newColours = prefs[colours];
		
		if (newFonts && [newFonts count] != 16) {
			NSLog(@"Unable to decode font block completely: using defaults");
			prefs[fonts] = DefaultFonts();
		}
		
		if (newColours && [newColours count] != 11) {
			NSLog(@"Unable to decode colour block completely: using defaults");
			prefs[colours] = DefaultColours();
		}
	}
	
	return self;
}

- (NSDictionary*) dictionary {
	// Fonts and colours need encoding
	NSMutableDictionary* newDict = [prefs mutableCopy];
	
	NSArray* fts = newDict[fonts];
	NSArray* cols = newDict[colours];
	
	if (fts != nil) {
		newDict[fonts] = [NSArchiver archivedDataWithRootObject: fts];
	}
	
	if (cols != nil) {
		newDict[colours] = [NSArchiver archivedDataWithRootObject: cols];
	}

	
	return [newDict autorelease];
}

- (void) dealloc {
	[prefs release];
	[prefLock release];
	
	[super dealloc];
}

// Getting preferences
- (BOOL) displayWarnings {
	[prefLock lock];
	BOOL result = [prefs[displayWarnings] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) fatalWarnings {
	[prefLock lock];
	BOOL result = [prefs[fatalWarnings] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) speakGameText {
	[prefLock lock];
	BOOL result =  [prefs[speakGameText] boolValue];
	[prefLock unlock];
	
	return result;
}

- (float) scrollbackLength {
	[prefLock lock];
	
	float result;
	if (prefs[scrollbackLength] == nil)
		result = 100.0;
	else
		result = [prefs[scrollbackLength] floatValue];
	
	[prefLock unlock];
	
	return result;
}

- (BOOL) confirmGameClose {
	BOOL result = YES;
	
	[prefLock lock];
	
	NSNumber* confirmValue = (NSNumber*)prefs[confirmGameClose];
	if (confirmValue) result = [confirmValue boolValue];
	
	[prefLock unlock];
	
	return result;
}

- (NSString*) gameTitle {
	[prefLock lock];
	NSString* result =  prefs[gameTitle];
	[prefLock unlock];
	
	return result;
}

- (int) interpreter {
	[prefLock lock];
	BOOL result = [prefs[interpreter] intValue];
	[prefLock unlock];
	
	return result;
}

- (enum GlulxInterpreter) glulxInterpreter {
	[prefLock lock];
	NSNumber* glulxInterpreterNum = (NSNumber*)prefs[glulxInterpreter];
	
	enum GlulxInterpreter result;
	if (glulxInterpreterNum)	result = [glulxInterpreterNum intValue];
	else						result = GlulxGit;
	
	[prefLock unlock];
	
	return result;
}

- (unsigned char) revision {
	[prefLock lock];
	unsigned char result = [prefs[revision] intValue];
	[prefLock unlock];
	
	return result;
}

- (NSArray*) fonts {
	[prefLock lock];
	NSArray* result = prefs[fonts];
	[prefLock unlock];
	
	return result;
}

- (NSArray*) colours {
	[prefLock lock];
	NSArray* result = prefs[colours];
	[prefLock unlock];
	
	return result;
}

- (NSString*) proportionalFontFamily {
	// Font 0 forms the prototype for this
	NSFont* prototypeFont = [self fonts][0];
	
	return [prototypeFont familyName];
}

- (NSString*) fixedFontFamily {
	// Font 4 forms the prototype for this
	NSFont* prototypeFont = [self fonts][4];
	
	return [prototypeFont familyName];
}

- (NSString*) symbolicFontFamily {
	// Font 8 forms the prototype for this
	NSFont* prototypeFont = [self fonts][8];
	
	return [prototypeFont familyName];
}

- (float) fontSize {
	// Font 0 forms the prototype for this
	NSFont* prototypeFont = [self fonts][0];
	
	return [prototypeFont pointSize];
}

- (NSString*) organiserDirectory {
	[prefLock lock];
	NSString* res = prefs[organiserDirectory];
	
	if (res == nil) {
		NSArray* docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		
		res = [docDir[0] stringByAppendingPathComponent: @"Interactive Fiction"];
	}
	[prefLock unlock];
	
	return res;
}

- (float) textMargin {
	[prefLock lock];
	NSNumber* result = (NSNumber*)prefs[textMargin];
	if (result == nil) result = @10.0f;
	[prefLock unlock];
	
	return [result floatValue];
}

- (BOOL) useScreenFonts {
	[prefLock lock];
	NSNumber* num = prefs[useScreenFonts];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;
}

- (BOOL) useHyphenation {
	[prefLock lock];
	NSNumber* num = prefs[useHyphenation];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;	
}

- (BOOL) useKerning {
	[prefLock lock];
	NSNumber* num = prefs[useKerning];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;	
}

- (BOOL) useLigatures {
	[prefLock lock];
	NSNumber* num = prefs[useLigatures];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;		
}

- (BOOL) keepGamesOrganised {
	[prefLock lock];
	BOOL result = [prefs[keepGamesOrganised] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) autosaveGames {
	[prefLock lock];
	NSNumber* autosave = prefs[autosaveGames];
	
	BOOL result = NO;			// Changed from 1.0.2beta1 as this was annoying
	if (autosave) result = [autosave boolValue];
	[prefLock unlock];
	
	return result;
}

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag {
	prefs[displayWarnings] = @(flag);
	[self preferencesHaveChanged];
}

- (void) setFatalWarnings: (BOOL) flag {
	prefs[fatalWarnings] = @(flag);
	[self preferencesHaveChanged];
}

- (void) setSpeakGameText: (BOOL) flag {
	prefs[speakGameText] = @(flag);
	[self preferencesHaveChanged];
}

- (void) setScrollbackLength: (float) length {
	prefs[scrollbackLength] = @(length);
	[self preferencesHaveChanged];
}

- (void) setConfirmGameClose: (BOOL) flag {
	prefs[confirmGameClose] = @(flag);
	[self preferencesHaveChanged];
}

- (void) setGameTitle: (NSString*) title {
	prefs[gameTitle] = [[title copy] autorelease];
	[self preferencesHaveChanged];
}

- (void) setGlulxInterpreter: (enum GlulxInterpreter) value {
	prefs[glulxInterpreter] = @((int) value);
	[self preferencesHaveChanged];
}

- (void) setInterpreter: (int) inter {
	prefs[interpreter] = @(inter);
	[self preferencesHaveChanged];
}

- (void) setRevision: (int) rev {
	prefs[revision] = @(rev);
	[self preferencesHaveChanged];
}

- (void) setFonts: (NSArray*) fts {
	prefs[fonts] = [NSArray arrayWithArray: fts];
	[self preferencesHaveChanged];
}

- (void) setColours: (NSArray*) cols {
	prefs[colours] = [NSArray arrayWithArray: cols];
	[self preferencesHaveChanged];
}

- (void) setOrganiserDirectory: (NSString*) directory {
	if (directory != nil) {
		prefs[organiserDirectory] = directory;
	} else {
		[prefs removeObjectForKey: organiserDirectory];
	}
	[self preferencesHaveChanged];
}

- (void) setKeepGamesOrganised: (BOOL) value {
	prefs[keepGamesOrganised] = @(value);
	[self preferencesHaveChanged];
}

- (void) setAutosaveGames: (BOOL) value {
	prefs[autosaveGames] = @(value);
	[self preferencesHaveChanged];
}

- (void) setTextMargin: (float) value {
	prefs[textMargin] = @(value);
	[self preferencesHaveChanged];
}

- (void) setUseScreenFonts: (BOOL) value {
	prefs[useScreenFonts] = @(value);
	[self preferencesHaveChanged];
}

- (void) setUseHyphenation: (BOOL) value {
	prefs[useHyphenation] = @(value);
	[self preferencesHaveChanged];
}

- (void) setUseKerning: (BOOL) value {
	prefs[useKerning] = @(value);
	[self preferencesHaveChanged];	
}

- (void) setUseLigatures: (BOOL) value {
	prefs[useLigatures] = @(value);
	[self preferencesHaveChanged];	
}

- (void) setFontRange: (NSRange) fontRange
			 toFamily: (NSString*) newFontFamily {
	// Sets a given range of fonts to the given family
	float size = [self fontSize];
	
	NSMutableArray* newFonts = [[[self fonts] mutableCopy] autorelease];
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSUInteger x;
	for (x=fontRange.location; x<fontRange.location+fontRange.length; x++) {
		// Get the traits for this font
		NSFontTraitMask traits = 0;
		
		if (x&1) traits |= NSBoldFontMask;
		if (x&2) traits |= NSItalicFontMask;
		if (x&4) traits |= NSFixedPitchFontMask;
		
		// Get a suitable font
		NSFont* newFont = [mgr fontWithFamily: newFontFamily
									   traits: traits
									   weight: 5
										 size: size];
		
		if (!newFont || [[newFont familyName] caseInsensitiveCompare: newFontFamily] != NSEqualToComparison) {
			// Retry with simpler conditions if we fail to get a font for some reason
			newFont = [mgr fontWithFamily: newFontFamily
								   traits: (x&4)!=0?NSFixedPitchFontMask:0
								   weight: 5
									 size: size];
		}
		
		// Store it
		if (newFont) {
			newFonts[x] = newFont;
		}
	}
	
	[self setFonts: newFonts];
}

- (void) setProportionalFontFamily: (NSString*) fontFamily {
	[self setFontRange: NSMakeRange(0,4)
			  toFamily: fontFamily];
}

- (void) setFixedFontFamily: (NSString*) fontFamily {
	[self setFontRange: NSMakeRange(4,4)
			  toFamily: fontFamily];
}

- (void) setSymbolicFontFamily: (NSString*) fontFamily {
	[self setFontRange: NSMakeRange(8,8)
			  toFamily: fontFamily];
}

- (void) setFontSize: (float) size {
	// Change the font size of all the fonts
	NSMutableArray* newFonts = [NSMutableArray array];
	
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	NSEnumerator* fontEnum = [[self fonts] objectEnumerator];
	NSFont* font;
	
	while (font = [fontEnum nextObject]) {
		NSFont* newFont = [mgr convertFont: font
									toSize: size];
		
		if (newFont) {
			[newFonts addObject: newFont];
		} else {
			[newFonts addObject: font];
		}
	}
	
	// Store the results
	[self setFonts: newFonts];
}

// = Display preferences =

- (int) foregroundColour {
	NSNumber* val = prefs[foregroundColour];
	if (val == nil) return 0;
	return [val intValue];
}

- (int) backgroundColour {
	NSNumber* val = prefs[backgroundColour];
	if (val == nil) return 7;
	return [val intValue];	
}

- (BOOL) showCoverPicture {
	NSNumber* val = prefs[showCoverPicture];
	if (val == nil) return YES;
	return [val boolValue];	
}

- (BOOL) showBorders {
	NSNumber* val = prefs[showBorders];
	if (val == nil) return YES;
	return [val boolValue];
}

- (BOOL) showGlkBorders {
	NSNumber* val = prefs[showGlkBorders];
	if (val == nil) return YES;
	return [val boolValue];	
}

- (void) setShowCoverPicture: (BOOL) value {
	prefs[showCoverPicture] = @(value);
	[self preferencesHaveChanged];	
}

- (void) setShowBorders: (BOOL) value {
	prefs[showBorders] = @(value);
	[self preferencesHaveChanged];	
}

- (void) setShowGlkBorders: (BOOL) value {
	prefs[showGlkBorders] = @(value);
	[self preferencesHaveChanged];	
}

- (void) setForegroundColour: (int) value {
	prefs[foregroundColour] = @(value);
	[self preferencesHaveChanged];		
}

- (void) setBackgroundColour: (int) value {
	prefs[backgroundColour] = @(value);
	[self preferencesHaveChanged];	
}

// = Notifications =

- (void) preferencesHaveChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomPreferencesHaveChangedNotification
														object:self];
	
	if (self == globalPreferences) {
		// Save global preferences
		[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
												  forKey:@"ZoomGlobalPreferences"];		
	}
}

// = NSCoding =
- (instancetype) initWithCoder: (NSCoder*) coder {
    self = [super init];
	
	if (self) {
		prefs = [[coder decodeObject] retain];
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: prefs];
}

@end
