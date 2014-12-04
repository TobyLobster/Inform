//
//  ZoomPreferences.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

extern NSString* ZoomPreferencesHaveChangedNotification;

enum GlulxInterpreter {
	GlulxGit		= 0,
	GlulxGlulxe		= 1
};

@interface ZoomPreferences : NSObject<NSCoding> {
	NSMutableDictionary* prefs;
	NSLock* prefLock;
}

// init is the designated initialiser for this class

+ (ZoomPreferences*) globalPreferences;
- (id) initWithDefaultPreferences;

- (id) initWithDictionary: (NSDictionary*) preferences;

// Getting preferences
+ (NSString*) defaultOrganiserDirectory;

// Warnings and game text prefs
- (BOOL)  displayWarnings;
- (BOOL)  fatalWarnings;
- (BOOL)  speakGameText;
- (BOOL)  confirmGameClose;
- (float) scrollbackLength;	// 0-100

// Interpreter preferences
- (NSString*)     gameTitle;
- (int)           interpreter;
- (enum GlulxInterpreter) glulxInterpreter;
- (unsigned char) revision;

// Typographical preferences
- (NSArray*)      fonts;   // 16 fonts
- (NSArray*)      colours; // 13 colours

- (NSString*) proportionalFontFamily;
- (NSString*) fixedFontFamily;
- (NSString*) symbolicFontFamily;
- (float) fontSize;

- (float) textMargin;
- (BOOL) useScreenFonts;
- (BOOL) useHyphenation;

- (BOOL) useKerning;
- (BOOL) useLigatures;

// Organiser preferences
- (NSString*) organiserDirectory;
- (BOOL)	  keepGamesOrganised;
- (BOOL)      autosaveGames;

// Display preferences
- (int) foregroundColour;
- (int) backgroundColour;
- (BOOL) showBorders;
- (BOOL) showGlkBorders;
- (BOOL) showCoverPicture;

// The dictionary
- (NSDictionary*) dictionary;

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag;
- (void) setFatalWarnings: (BOOL) flag;
- (void) setSpeakGameText: (BOOL) flag;
- (void) setConfirmGameClose: (BOOL) flag;
- (void) setScrollbackLength: (float) value;
- (void) setGlulxInterpreter: (enum GlulxInterpreter) value;

- (void) setGameTitle: (NSString*) title;
- (void) setInterpreter: (int) interpreter;
- (void) setRevision: (int) revision;

- (void) setFonts: (NSArray*) fonts;
- (void) setColours: (NSArray*) colours;

- (void) setProportionalFontFamily: (NSString*) fontFamily;
- (void) setFixedFontFamily: (NSString*) fontFamily;
- (void) setSymbolicFontFamily: (NSString*) fontFamily;
- (void) setFontSize: (float) size;

- (void) setTextMargin: (float) textMargin;
- (void) setUseScreenFonts: (BOOL) useScreenFonts;
- (void) setUseHyphenation: (BOOL) useHyphenation;
- (void) setUseKerning: (BOOL) useKerning;
- (void) setUseLigatures: (BOOL) useLigatures;

- (void) setOrganiserDirectory: (NSString*) directory;
- (void) setKeepGamesOrganised: (BOOL) value;
- (void) setAutosaveGames: (BOOL) value;

- (void) setShowBorders: (BOOL) value;
- (void) setShowGlkBorders: (BOOL) value;
- (void) setForegroundColour: (int) value;
- (void) setBackgroundColour: (int) value;
- (void) setShowCoverPicture: (BOOL) value;

// Notifications
- (void) preferencesHaveChanged;

@end
