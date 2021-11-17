//
//  ZoomPreferenceWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Dec 20 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <ZoomView/ZoomPreferences.h>

@interface ZoomPreferenceWindow : NSWindowController <NSToolbarDelegate, NSTableViewDataSource, NSTableViewDelegate> {
	// The various views
	IBOutlet NSView* generalSettingsView;
	IBOutlet NSView* gameSettingsView;
	IBOutlet NSView* fontSettingsView;
	IBOutlet NSView* colourSettingsView;
	IBOutlet NSView* typographicalSettingsView;
	IBOutlet NSView* displaySettingsView;
	
	// The settings controls themselves
	IBOutlet NSButton* displayWarnings;
	IBOutlet NSButton* fatalWarnings;
	IBOutlet NSButton* speakGameText;	
	IBOutlet NSSlider* scrollbackLength;
	IBOutlet NSButton* autosaveGames;
	IBOutlet NSButton* keepGamesOrganised;
	IBOutlet NSButton* confirmGameClose;
	IBOutlet NSSlider* transparencySlider;
	
	IBOutlet NSPopUpButton* proportionalFont;
	IBOutlet NSPopUpButton* fixedFont;
	IBOutlet NSPopUpButton* symbolicFont;
	IBOutlet NSSlider* fontSizeSlider;
	IBOutlet NSTextField* fontSizeDisplay;
	IBOutlet NSTextField* fontPreview;
		
	IBOutlet NSPopUpButton* glulxInterpreter;
	IBOutlet NSPopUpButton* interpreter;
	IBOutlet NSTextField* revision;
	IBOutlet NSButton* reorganiseGames;
	IBOutlet NSProgressIndicator* organiserIndicator;
	int      indicatorCount;
	
	IBOutlet NSTextView* organiseDir;
	
	IBOutlet NSTableView* fonts;
	IBOutlet NSTableView* colours;
	
	IBOutlet NSButton* showMargins;
	IBOutlet NSSlider* marginWidth;
	IBOutlet NSButton* useScreenFonts;
	IBOutlet NSButton* useHyphenation;
	IBOutlet NSButton* kerning;
	IBOutlet NSButton* ligatures;
	
	IBOutlet NSPopUpButton* foregroundColour;
	IBOutlet NSPopUpButton* backgroundColour;
	IBOutlet NSButton* zoomBorders;
	IBOutlet NSButton* showCoverPicture;
	
	/// The toolbar
	NSToolbar* toolbar;
	
	/// The preferences that we're editing
	ZoomPreferences* prefs;
}

@property (nonatomic, strong) ZoomPreferences *preferences;

// Interface actions
- (IBAction) glulxInterpreterChanged: (id) sender;
- (IBAction) interpreterChanged: (id) sender;
- (IBAction) revisionChanged: (id) sender;
- (IBAction) displayWarningsChanged: (id) sender;
- (IBAction) fatalWarningsChanged: (id) sender;
- (IBAction) speakGameTextChanged: (id) sender;
- (IBAction) scrollbackChanged: (id) sender;
- (IBAction) keepOrganisedChanged: (id) sender;
- (IBAction) autosaveChanged: (id) sender;
- (IBAction) confirmGameCloseChanged: (id) sender;
- (IBAction) changeTransparency: (id)sender;

- (IBAction) simpleFontsChanged: (id) sender;

- (IBAction) changeOrganiseDir: (id) sender;
- (IBAction) resetOrganiseDir: (id) sender;
- (IBAction) reorganiseGames: (id) sender;

- (IBAction) marginsChanged: (id) sender;
- (IBAction) screenFontsChanged: (id) sender;
- (IBAction) hyphenationChanged: (id) sender;
- (IBAction) ligaturesChanged: (id) sender;
- (IBAction) kerningChanged: (id) sender;

- (IBAction) bordersChanged: (id) sender;
- (IBAction) showCoverPictureChanged: (id) sender;
- (IBAction) colourChanged: (id) sender;

@end
