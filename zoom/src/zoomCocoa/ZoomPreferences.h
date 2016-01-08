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
- (instancetype) initWithDefaultPreferences;

- (instancetype) initWithDictionary: (NSDictionary*) preferences NS_DESIGNATED_INITIALIZER;

// Getting preferences
+ (NSString*) defaultOrganiserDirectory;

// Warnings and game text prefs
@property (NS_NONATOMIC_IOSONLY) BOOL displayWarnings;
@property (NS_NONATOMIC_IOSONLY) BOOL fatalWarnings;
@property (NS_NONATOMIC_IOSONLY) BOOL speakGameText;
@property (NS_NONATOMIC_IOSONLY) BOOL confirmGameClose;
@property (NS_NONATOMIC_IOSONLY) float scrollbackLength;	// 0-100

// Interpreter preferences
@property (NS_NONATOMIC_IOSONLY, copy) NSString *gameTitle;
@property (NS_NONATOMIC_IOSONLY) int interpreter;
@property (NS_NONATOMIC_IOSONLY) enum GlulxInterpreter glulxInterpreter;
- (unsigned char) revision;

// Typographical preferences
@property (NS_NONATOMIC_IOSONLY, copy) NSArray *fonts;   // 16 fonts
@property (NS_NONATOMIC_IOSONLY, copy) NSArray *colours; // 13 colours

@property (NS_NONATOMIC_IOSONLY, copy) NSString *proportionalFontFamily;
@property (NS_NONATOMIC_IOSONLY, copy) NSString *fixedFontFamily;
@property (NS_NONATOMIC_IOSONLY, copy) NSString *symbolicFontFamily;
@property (NS_NONATOMIC_IOSONLY) float fontSize;

@property (NS_NONATOMIC_IOSONLY) float textMargin;
@property (NS_NONATOMIC_IOSONLY) BOOL useScreenFonts;
@property (NS_NONATOMIC_IOSONLY) BOOL useHyphenation;

@property (NS_NONATOMIC_IOSONLY) BOOL useKerning;
@property (NS_NONATOMIC_IOSONLY) BOOL useLigatures;

// Organiser preferences
@property (NS_NONATOMIC_IOSONLY, copy) NSString *organiserDirectory;
@property (NS_NONATOMIC_IOSONLY) BOOL keepGamesOrganised;
@property (NS_NONATOMIC_IOSONLY) BOOL autosaveGames;

// Display preferences
@property (NS_NONATOMIC_IOSONLY) int foregroundColour;
@property (NS_NONATOMIC_IOSONLY) int backgroundColour;
@property (NS_NONATOMIC_IOSONLY) BOOL showBorders;
@property (NS_NONATOMIC_IOSONLY) BOOL showGlkBorders;
@property (NS_NONATOMIC_IOSONLY) BOOL showCoverPicture;

// The dictionary
- (NSDictionary*) dictionary;

// Setting preferences

- (void) setRevision: (int) revision;






// Notifications
- (void) preferencesHaveChanged;

@end
