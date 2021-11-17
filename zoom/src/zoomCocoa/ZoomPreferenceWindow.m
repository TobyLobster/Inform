//
//  ZoomPreferenceWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Dec 20 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Modifications by Collin Pieper to add transparency support

#import <tgmath.h>
#import "ZoomPreferenceWindow.h"
#import "ZoomStoryOrganiser.h"
#import <ZoomView/ZoomPreferences.h>
#import <ZoomView/ZoomView-Swift.h>


static NSToolbarItem* generalSettingsItem;
static NSToolbarItemIdentifier const generalSettingsItemName = @"generalSettings";
static NSToolbarItem* gameSettingsItem;
static NSToolbarItemIdentifier const gameSettingsItemName = @"gameSettings";
static NSToolbarItem* displaySettingsItem;
static NSToolbarItemIdentifier const displaySettingsItemName = @"displaySettings";
static NSToolbarItem* fontSettingsItem;
static NSToolbarItemIdentifier const fontSettingsItemName = @"fontSettings";
static NSToolbarItem* colourSettingsItem;
static NSToolbarItemIdentifier const colourSettingsItemName = @"colourSettings";
static NSToolbarItem* typographicSettingsItem;
static NSToolbarItemIdentifier const typographicSettingsItemName = @"typographicSettings";

static NSDictionary<NSToolbarItemIdentifier,NSToolbarItem*>*  itemDictionary = nil;

@implementation ZoomPreferenceWindow

+ (void) initialize {
	// Create the toolbar items
	generalSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: generalSettingsItemName];
	gameSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: gameSettingsItemName];
	displaySettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: displaySettingsItemName];
	fontSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: fontSettingsItemName];
	colourSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: colourSettingsItemName];
	typographicSettingsItem = [[NSToolbarItem alloc] initWithItemIdentifier: typographicSettingsItemName];
	
	// ... and the dictionary
	itemDictionary = @{
		generalSettingsItemName: generalSettingsItem,
		gameSettingsItemName: gameSettingsItem,
		displaySettingsItemName: displaySettingsItem,
		fontSettingsItemName: fontSettingsItem,
		colourSettingsItemName: colourSettingsItem,
		typographicSettingsItemName: typographicSettingsItem};
	
	// Set up the items
	[generalSettingsItem setLabel: NSLocalizedString(@"Preferences: General", @"General")];
	[generalSettingsItem setImage: [NSImage imageNamed:@"Settings/general"]];
	[gameSettingsItem setLabel: NSLocalizedString(@"Preferences: Game", @"Game")];
	[gameSettingsItem setImage: [NSImage imageNamed:@"Settings/game"]];
	[displaySettingsItem setLabel: NSLocalizedString(@"Preferences: Display", @"Display")];
	[displaySettingsItem setImage: [NSImage imageNamed:@"Settings/display"]];
	[fontSettingsItem setLabel: NSLocalizedString(@"Preferences: Fonts", @"Fonts")];
	[fontSettingsItem setImage: [NSImage imageNamed:@"Settings/font"]];
	[colourSettingsItem setLabel: NSLocalizedString(@"Preferences: Colour", @"Colour")];
	[colourSettingsItem setImage: [NSImage imageNamed:NSImageNameColorPanel]];
	[typographicSettingsItem setLabel: NSLocalizedString(@"Preferences: Typography", @"Typography")];
	[typographicSettingsItem setImage: [NSImage imageNamed:@"Settings/typographic"]];
	
	// And the actions
	[generalSettingsItem setAction: @selector(generalSettings:)];
	[gameSettingsItem setAction: @selector(gameSettings:)];
	[displaySettingsItem setAction: @selector(displaySettings:)];
	[fontSettingsItem setAction: @selector(fontSettings:)];
	[colourSettingsItem setAction: @selector(colourSettings:)];	
	[typographicSettingsItem setAction: @selector(typographicSettings:)];	
}

- (id) init {
	return [self initWithWindowNibName: @"Preferences"];
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (NSMenu*) fontMenu: (BOOL) fixed {
	// Constructs a menu of fonts
	// (Apple want us to use the font selection panel, but it feels clunky for the 'simple' view: there's no good way to associate
	// it with the style we're selecting. Plus we want to select families, not individual fonts)
	NSFontManager* mgr = [NSFontManager sharedFontManager];

	NSMenu* result = [[NSMenu alloc] init];
	
	// Iterate through the available font families and create menu items
	NSEnumerator<NSString*>* familyEnum = [[[mgr availableFontFamilies] sortedArrayUsingSelector: @selector(caseInsensitiveCompare:)] objectEnumerator];
	
	for (NSString* family in familyEnum) {
		// Get the font
		NSFont* sampleFont = [mgr fontWithFamily: family
										  traits: 0
										  weight: 5
											size: 13.0];
		
		if (!sampleFont) continue;
		if (fixed && ![sampleFont isFixedPitch]) {
			// Skip this font
			continue;
		}
		
		// Construct the item
		NSMenuItem* fontItem = [[NSMenuItem alloc] init];
		[fontItem setAttributedTitle: 
			[[NSAttributedString alloc] initWithString: family
											attributes: @{NSFontAttributeName: sampleFont}]];
		
		// Add to the menu
		[result addItem: fontItem];
	}
	
	// Return the result
	return result;
}

- (void) windowDidLoad {
	// Set the toolbar
	toolbar = [[NSToolbar alloc] initWithIdentifier: @"preferencesToolbar2"];
		
	[toolbar setDelegate: self];
	[toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	[toolbar setAllowsUserCustomization: NO];
	
	[[self window] setToolbar: toolbar];
	if (@available(macOS 11.0, *)) {
		self.window.toolbarStyle = NSWindowToolbarStylePreference;
	}
	
	[[self window] setContentSize: [generalSettingsView frame].size];
	[[self window] setContentView: generalSettingsView];

	[toolbar setSelectedItemIdentifier: generalSettingsItemName];
	
	
	[fonts setDataSource: self];
	[fonts setDelegate: self];
	[colours setDataSource: self];
	[colours setDelegate: self];
	
	// Set up the various font menus
	NSMenu* proportionalMenu = [self fontMenu: NO];
	NSMenu* fixedMenu = [self fontMenu: YES];
	NSMenu* symbolMenu = [proportionalMenu copy];
	
	[proportionalFont setMenu: proportionalMenu];
	[fixedFont setMenu: fixedMenu];
	[symbolicFont setMenu: symbolMenu];
	
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(storyProgressChanged:)
												 name: ZoomStoryOrganiserProgressNotification
											   object: [ZoomStoryOrganiser sharedStoryOrganiser]];
}

// == Setting the pane that's being displayed ==

- (void) switchToPane: (NSView*) preferencePane {
	if ([[self window] contentView] == preferencePane) return;
	
	// Select the appropriate item in the toolbar
	{
		NSToolbarItemIdentifier selected = nil;
		
		if (preferencePane == generalSettingsView) {
			selected = generalSettingsItemName;
		} else if (preferencePane == gameSettingsView) {
			selected = gameSettingsItemName;
		} else if (preferencePane == displaySettingsView) {
			selected = displaySettingsItemName;
		} else if (preferencePane == fontSettingsView) {
			selected = fontSettingsItemName;
		} else if (preferencePane == colourSettingsView) {
			selected = colourSettingsItemName;
		} else if (preferencePane == typographicalSettingsView) {
			selected = typographicSettingsItemName;
		}
		
		if (selected != nil) {
			[toolbar setSelectedItemIdentifier: selected];
		}
	}
	
	// Work out the various frame sizes
	NSRect currentFrame = [[[self window] contentView] frame];
	NSRect oldFrame = currentFrame;
	NSRect windowFrame = [[self window] frame];
	
	currentFrame.origin.y    -= [preferencePane frame].size.height - currentFrame.size.height;
	currentFrame.size.height  = [preferencePane frame].size.height;
	
	// Grr, complicated, as OS X provides no way to work out toolbar proportions except in 10.3
	windowFrame.origin.x    += (currentFrame.origin.x - oldFrame.origin.x);
	windowFrame.origin.y    += (currentFrame.origin.y - oldFrame.origin.y);
	windowFrame.size.width  += (currentFrame.size.width - oldFrame.size.width);
	windowFrame.size.height += (currentFrame.size.height - oldFrame.size.height);
	
	[[self window] setContentView: [[NSView alloc] init]];
	[[self window] setFrame: windowFrame
					display: YES
					animate: YES];
	[[self window] setContentView: preferencePane];
	[[self window] setInitialFirstResponder: preferencePane];
}

// == Toolbar delegate functions ==

- (NSToolbarItem *)toolbar: (NSToolbar *) toolbar
     itemForItemIdentifier: (NSString *)  itemIdentifier
 willBeInsertedIntoToolbar: (BOOL)        flag {
    return [itemDictionary objectForKey: itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return @[generalSettingsItemName, gameSettingsItemName, displaySettingsItemName, fontSettingsItemName, typographicSettingsItemName, colourSettingsItemName, NSToolbarFlexibleSpaceItemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    return @[NSToolbarFlexibleSpaceItemIdentifier, generalSettingsItemName, gameSettingsItemName, displaySettingsItemName, fontSettingsItemName, typographicSettingsItemName, colourSettingsItemName, NSToolbarFlexibleSpaceItemIdentifier];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return @[generalSettingsItemName, gameSettingsItemName, displaySettingsItemName, fontSettingsItemName, colourSettingsItemName, typographicSettingsItemName];	
}

// == Toolbar actions ==

- (void) generalSettings: (id) sender {
	[self switchToPane: generalSettingsView];
}

- (void) gameSettings: (id) sender {
	[self switchToPane: gameSettingsView];
}

- (void) displaySettings: (id) sender {
	[self switchToPane: displaySettingsView];
}

- (void) fontSettings: (id) sender {
	[self switchToPane: fontSettingsView];
}

- (void) colourSettings: (id) sender {
	[self switchToPane: colourSettingsView];
}

- (void) typographicSettings: (id) sender {
	[self switchToPane: typographicalSettingsView];
}

// == Setting the preferences that we're editing ==

- (void) setButton: (NSPopUpButton*) button
	  toFontFamily: (NSString*) family {
	NSMenuItem* familyItem = nil;
	
	for (NSMenuItem* curItem in [[button menu] itemArray]) {
		if ([[curItem title] caseInsensitiveCompare: family] == NSEqualToComparison) {
			familyItem = curItem;
			break;
		}
	}
	
	if (familyItem) {
		[button selectItem: familyItem];
	}
}

- (void) setSimpleFonts {
	// Sets our display from the 'simple' fonts the user has selected
	
	// Select the fonts
	[self setButton: proportionalFont 
	   toFontFamily: [prefs proportionalFontFamily]];
	[self setButton: fixedFont
	   toFontFamily: [prefs fixedFontFamily]];
	[self setButton: symbolicFont 
	   toFontFamily: [prefs symbolicFontFamily]];
	
	// Set the size display
	CGFloat fontSize = [prefs fontSize];
	[fontSizeSlider setFloatValue: fontSize];
	[fontSizeDisplay setStringValue: [NSString stringWithFormat: @"%.1fpt", fontSize]];
	
	// Set the font preview
	[fontPreview setFont: [[prefs fonts] objectAtIndex: 0]];
}

- (NSString*) colourNameAtIndex: (NSInteger) index {
	switch (index) {
		case 0: return NSLocalizedString(@"Color Black", @"Black");
		case 1: return NSLocalizedString(@"Color Red", @"Red");
		case 2: return NSLocalizedString(@"Color Green", @"Green");
		case 3: return NSLocalizedString(@"Color Yellow", @"Yellow");
		case 4: return NSLocalizedString(@"Color Blue", @"Blue");
		case 5: return NSLocalizedString(@"Color Magenta", @"Magenta");
		case 6: return NSLocalizedString(@"Color Cyan", @"Cyan");
		case 7: return NSLocalizedString(@"Color White", @"White");
		case 8: return NSLocalizedString(@"Color Light grey", @"Light grey");
		case 9: return NSLocalizedString(@"Color Medium grey", @"Medium grey");
		case 10: return NSLocalizedString(@"Color Dark grey", @"Dark grey");
		default: return NSLocalizedString(@"Color Unused colour", @"Unused colour");
	}
}

- (void) selectItemWithTag: (int) tag
				   inPopup: (NSPopUpButton*) button {
	int index;
	
	for (index=0; index < [[button itemArray] count]; index++) {
		if ([[button itemAtIndex: index] tag] == tag) {
			[button selectItemAtIndex: index];
			return;
		}
	}
}

- (void) updateColourMenus {
	NSMenu* newColourMenu = [[NSMenu alloc] init];
	
	int col;
	for (col=0; col<10; col++) {
		// Build the image showing a preview of this colour
		NSImage* sampleImage = [[NSImage alloc] initWithSize: NSMakeSize(16, 12)];
		
		[sampleImage lockFocus];
		[[[prefs colours] objectAtIndex: col] set];
		NSRectFill(NSMakeRect(0,0,16,12));
		[sampleImage unlockFocus];
		
		// Build the actual menu item
		NSMenuItem* colourItem = [[NSMenuItem alloc] initWithTitle: [self colourNameAtIndex: col]
															action: nil
													 keyEquivalent: @""];
		[colourItem setTag: col];
		[colourItem setImage: sampleImage];
		
		// Add it to the menu
		[newColourMenu addItem: colourItem];
	}
	
	// Set the menu as the menu for both the popup buttons
	[foregroundColour setMenu: newColourMenu];
	[backgroundColour setMenu: [newColourMenu copy]];

	[self selectItemWithTag: [prefs foregroundColour]
					inPopup: foregroundColour];
	[self selectItemWithTag: [prefs backgroundColour]
					inPopup: backgroundColour];
}

@synthesize preferences = prefs;
- (void) setPreferences: (ZoomPreferences*) preferences {
	prefs = preferences;
	
	[displayWarnings setState: [prefs displayWarnings]?NSControlStateValueOn:NSControlStateValueOff];
	[fatalWarnings setState: [prefs fatalWarnings]?NSControlStateValueOn:NSControlStateValueOff];
	[speakGameText setState: [prefs speakGameText]?NSControlStateValueOn:NSControlStateValueOff];
	[scrollbackLength setFloatValue: [prefs scrollbackLength]];
	[keepGamesOrganised setState: [prefs keepGamesOrganised]?NSControlStateValueOn:NSControlStateValueOff];
	[autosaveGames setState: [prefs autosaveGames]?NSControlStateValueOn:NSControlStateValueOff];
	[reorganiseGames setEnabled: [prefs keepGamesOrganised]];
	[confirmGameClose setState: [prefs confirmGameClose]?NSControlStateValueOn:NSControlStateValueOff];
	[glulxInterpreter selectItemAtIndex: [glulxInterpreter indexOfItemWithTag: [prefs glulxInterpreter]]];
	
	// a kind of chessy way to get the current alpha setting
	CGFloat red, green, blue, alpha;
	NSColor * color = [[prefs colours] objectAtIndex:0];
	[color getRed:&red green:&green blue:&blue alpha:&alpha];
	[transparencySlider setFloatValue:(alpha * 100.0)];
	
	[interpreter selectItemAtIndex: [prefs interpreter]-1];
	[revision setStringValue: [NSString stringWithFormat: @"%c", [prefs revision]]];
	
	[self setSimpleFonts];
	
	[organiseDir setString: [prefs organiserDirectory]];
	
	[showMargins setState: [prefs textMargin] > 0?NSControlStateValueOn:NSControlStateValueOff];
	[useScreenFonts setState: [prefs useScreenFonts]?NSControlStateValueOn:NSControlStateValueOff];
	[useHyphenation setState: [prefs useHyphenation]?NSControlStateValueOn:NSControlStateValueOff];
	[kerning setState: [prefs useKerning]?NSControlStateValueOn:NSControlStateValueOff];
	[ligatures setState: [prefs useLigatures]?NSControlStateValueOn:NSControlStateValueOff];
	
	[marginWidth setEnabled: [prefs textMargin] > 0];
	if ([prefs textMargin] > 0) {
		[marginWidth setFloatValue: [prefs textMargin]];
	}
	
	[zoomBorders setState: [prefs showBorders]?NSControlStateValueOn:NSControlStateValueOff];
	[showCoverPicture setState: [prefs showCoverPicture]?NSControlStateValueOn:NSControlStateValueOff];
	[self updateColourMenus];
}

// == Table data source ==

- (NSInteger)numberOfRowsInTableView: (NSTableView *)aTableView {
	if (aTableView == fonts) return [[prefs fonts] count];
	if (aTableView == colours) return [[prefs colours] count];
	
	return 0;
}

static void appendStyle(NSMutableString* styleName,
						NSString* newStyle) {
	if ([styleName length] == 0) {
		[styleName appendString: newStyle];
	} else {
		[styleName appendString: @"-"];
		[styleName appendString: newStyle];
	}
}

- (id)              tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
						  row:(NSInteger)rowIndex {
	if (aTableView == fonts) {
		// Fonts table
		NSArray* fontArray = [prefs fonts];
		
		if ([[aTableColumn identifier] isEqualToString: @"Style"]) {
			NSMutableString* name = [NSMutableString stringWithCapacity:20];
			
			if (rowIndex&1) appendStyle(name, @"bold");
			if (rowIndex&2) appendStyle(name, @"italic");
			if (rowIndex&4) appendStyle(name, @"fixed");
			if (rowIndex&8) appendStyle(name, @"symbolic");
			
			if ([name isEqualToString: @""]) [name setString:@"roman"];
			
			return [name copy];
		} else if ([[aTableColumn identifier] isEqualToString: @"Font"]) {
			NSString* fontName;
			NSFont* font = [fontArray objectAtIndex: rowIndex];
			
			fontName = [NSString stringWithFormat: @"%@ (%.2gpt)", 
				[font fontName],
				[font pointSize]];
			
			NSAttributedString* res;
			
			res = [[NSAttributedString alloc] initWithString: fontName
												  attributes: @{NSFontAttributeName: font}];
			
			return res;
		}
		
		return @" -- ";
	}
	
	if (aTableView == colours) {
		if ([[aTableColumn identifier] isEqualToString: @"Colour name"]) {
			return [self colourNameAtIndex: rowIndex];
		} else if ([[aTableColumn identifier] isEqualToString: @"Colour"]) {
			NSColor* theColour = [[prefs colours] objectAtIndex: rowIndex];
			NSAttributedString* res;
			
			res = [[NSAttributedString alloc] initWithString: @"Sample"
												  attributes: @{
				NSForegroundColorAttributeName: theColour,
				NSBackgroundColorAttributeName: theColour
			}];
			
			return res;
		}
		
		return @" -- ";
	}
	
	return @" -- ";
}

// == Table delegate ==

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if ([aNotification object] == fonts) {
		NSInteger selFont = [fonts selectedRow];
		
		if (selFont < 0) {
			return;
		}

		NSFont* font = [[prefs fonts] objectAtIndex: selFont];
		
		// Display font panel
		[[NSFontPanel sharedFontPanel] setPanelFont: font
										 isMultiple: NO];
		[[NSFontPanel sharedFontPanel] setEnabled: YES];
		[[NSFontPanel sharedFontPanel] setAccessoryView: nil];
		[[NSFontPanel sharedFontPanel] orderFront: self];
		[[NSFontPanel sharedFontPanel] reloadDefaultFontFamilies];
	} else if ([aNotification object] == colours) {
		NSInteger selColour = [colours selectedRow];
		
		if (selColour < 0) {
			return;
		}
		
		NSColor* colour = [[prefs colours] objectAtIndex: selColour];
		
		// Display colours
		[[NSColorPanel sharedColorPanel] setColor: colour];
		[[NSColorPanel sharedColorPanel] setAccessoryView: nil];
		[[NSColorPanel sharedColorPanel] orderFront: self];
	}
}

// == Font panel delegate ==

- (void) changeFont:(id) sender {
	// Change the selected font in the font table
	NSInteger selFont = [fonts selectedRow];
	
	if (selFont < 0) return;
	
	NSMutableArray* prefFonts = [[prefs fonts] mutableCopy];
	NSFont* newFont;
	
	newFont = [sender convertFont: [prefFonts objectAtIndex: selFont]];

	if (newFont) {
		[prefFonts replaceObjectAtIndex: selFont
						 withObject: newFont];
		[prefs setFonts: prefFonts];
		
		[fonts reloadData];
	}
	
	[self setSimpleFonts];
}

- (void)changeColor:(id)sender {	
	NSInteger selColour = [colours selectedRow];
	
	if (selColour < 0) {
		return;
	}
	
	NSColor* selected_colour = [[NSColorPanel sharedColorPanel] color];
	NSColor* colour = [[selected_colour colorUsingColorSpace: [NSColorSpace genericRGBColorSpace]] colorWithAlphaComponent:(([transparencySlider floatValue] / 100.0))];
	
	NSMutableArray* cols = [[prefs colours] mutableCopy];
	
	if (colour) {
		[cols replaceObjectAtIndex: selColour
						withObject: colour];
		[prefs setColours: cols];
		
		[colours reloadData];
		[self updateColourMenus];
	}
}

- (void)changeTransparency:(id)sender {
	NSMutableArray* cols = [[prefs colours] mutableCopy];
	
	int i;
	for(  i = 0; i < [cols count]; i++ )
	{
		NSColor * color = [cols objectAtIndex: i];
	
		NSColor*  transparent_color = [[color colorUsingColorSpace: [NSColorSpace genericRGBColorSpace]] colorWithAlphaComponent:([transparencySlider floatValue] / 100.0)];
		
		[cols replaceObjectAtIndex: i
						withObject: transparent_color];
	}

	[prefs setColours: cols];
		
	[colours reloadData];
}

// == Various actions ==

- (IBAction) interpreterChanged: (id) sender {
	[prefs setInterpreter: [interpreter indexOfSelectedItem]+1];
}

- (IBAction) glulxInterpreterChanged: (id) sender {
	[prefs setGlulxInterpreter: [[glulxInterpreter selectedItem] tag]];
}

- (IBAction) revisionChanged: (id) sender {
	[prefs setRevision: [[revision stringValue] characterAtIndex: 0]];
}

- (IBAction) displayWarningsChanged: (id) sender {
	[prefs setDisplayWarnings: [sender state]==NSControlStateValueOn];
}

- (IBAction) fatalWarningsChanged: (id) sender {
	[prefs setFatalWarnings: [sender state]==NSControlStateValueOn];
}

- (IBAction) speakGameTextChanged: (id) sender {
	[prefs setSpeakGameText: [sender state]==NSControlStateValueOn];
}

- (IBAction) scrollbackChanged: (id) sender {
	[prefs setScrollbackLength: [sender floatValue]];
}

- (IBAction) autosaveChanged: (id) sender {
	[prefs setAutosaveGames: [sender state]==NSControlStateValueOn];
}

- (IBAction) confirmGameCloseChanged: (id) sender {
	[prefs setConfirmGameClose: [sender state]==NSControlStateValueOn];
}

- (IBAction) keepOrganisedChanged: (id) sender {
	[prefs setKeepGamesOrganised: [sender state]==NSControlStateValueOn];
	[reorganiseGames setEnabled: [sender state]==NSControlStateValueOn];
	if ([sender state]==NSControlStateValueOff) {
		[autosaveGames setState: NSControlStateValueOff];
		[prefs setAutosaveGames: NO];
	}
}

- (IBAction) changeOrganiseDir: (id) sender {
	NSOpenPanel* dirChooser = [NSOpenPanel openPanel];
	
	[dirChooser setAllowsMultipleSelection: NO];
	[dirChooser setCanChooseDirectories: YES];
	[dirChooser setCanChooseFiles: NO];
	[dirChooser setCanCreateDirectories: YES];
	
	NSString* path = [prefs organiserDirectory];
	if (path) {
		NSURL *pathURL = [NSURL fileURLWithPath:path];
		dirChooser.directoryURL = pathURL;
	}
	
	[dirChooser beginSheetModalForWindow: self.window completionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) {
			return;
		}
		
		[[ZoomStoryOrganiser sharedStoryOrganiser] reorganiseStoriesToNewDirectory: [dirChooser URL].path];
		[self->prefs setOrganiserDirectory: [dirChooser URL].path];
		[self->organiseDir setString: [self->prefs organiserDirectory]];
	}];
}

- (IBAction) resetOrganiseDir: (id) sender {
	if ([prefs keepGamesOrganised]) {
		[[ZoomStoryOrganiser sharedStoryOrganiser] reorganiseStoriesToNewDirectory: [ZoomPreferences defaultOrganiserDirectory]];
	}
	[prefs setOrganiserDirectory: nil];
	[organiseDir setString: [prefs organiserDirectory]];
}


- (IBAction) simpleFontsChanged: (id) sender {
	// This action applies to all the font controls
	
	// Set the size, if it has changed
	CGFloat newSize = floor([fontSizeSlider doubleValue]);
	if (newSize != [prefs fontSize]) [prefs setFontSize: newSize];
	
	// Set the families, if they've changed
	NSString* propFamily = [[proportionalFont selectedItem] title];
	NSString* fixedFamily = [[fixedFont selectedItem] title];
	NSString* symbolicFamily = [[symbolicFont selectedItem] title];
	
	if (![propFamily isEqualToString: [prefs proportionalFontFamily]]) [prefs setProportionalFontFamily: propFamily];
	if (![fixedFamily isEqualToString: [prefs fixedFontFamily]]) [prefs setFixedFontFamily: fixedFamily];
	if (![symbolicFamily isEqualToString: [prefs symbolicFontFamily]]) [prefs setSymbolicFontFamily: symbolicFamily];
	
	// Update the display
	[self setSimpleFonts];
}

#pragma mark - Typographical changes

- (IBAction) marginsChanged: (id) sender {
	// Work out the new margin size
	CGFloat oldSize = [prefs textMargin];
	CGFloat newSize;
	
	if ([showMargins state] == NSControlStateValueOff) {
		newSize = 0;
		[marginWidth setEnabled: NO];
	} else if ([showMargins state] == NSControlStateValueOn && oldSize <= 0) {
		newSize = 10.0;
		[marginWidth setEnabled: YES];
	} else {
		newSize = floor([marginWidth doubleValue]);
		[marginWidth setEnabled: YES];
	}
	
	if (newSize != oldSize) {
		[prefs setTextMargin: newSize];
	}
}

- (IBAction) screenFontsChanged: (id) sender {
	BOOL newState = [useScreenFonts state]==NSControlStateValueOn;
	
	if (newState != [prefs useScreenFonts]) {
		[prefs setUseScreenFonts: newState];
	}	
}

- (IBAction) hyphenationChanged: (id) sender {
	BOOL newState = [useHyphenation state]==NSControlStateValueOn;
	
	if (newState != [prefs useHyphenation]) {
		[prefs setUseHyphenation: newState];
	}
}

- (IBAction) ligaturesChanged: (id) sender {
	BOOL newState = [ligatures state]==NSControlStateValueOn;
	
	if (newState != [prefs useLigatures]) {
		[prefs setUseLigatures: newState];
	}	
}

- (IBAction) kerningChanged: (id) sender {
	BOOL newState = [kerning state]==NSControlStateValueOn;
	
	if (newState != [prefs useKerning]) {
		[prefs setUseKerning: newState];
	}	
}

#pragma mark - Story progress meter

- (void) storyProgressChanged: (NSNotification*) not {
	NSDictionary* userInfo = [not userInfo];
	BOOL activated = [[userInfo objectForKey: @"ActionStarting"] boolValue];
	
	if (activated) {
		indicatorCount++;
	} else {
		indicatorCount--;
	}
	
	if (indicatorCount <= 0) {
		indicatorCount = 0;
		[organiserIndicator stopAnimation: self];
	} else {
		[organiserIndicator startAnimation: self];
	}
}

- (IBAction) reorganiseGames: (id) sender {
	// Can't use this if keepGamesOrganised is off
	if (![prefs keepGamesOrganised]) return;
	
	// Reorganise all the stories
	[[ZoomStoryOrganiser sharedStoryOrganiser] organiseAllStories];
}

#pragma mark - Display pane

- (IBAction) bordersChanged: (id) sender {
	BOOL newState = [sender state] == NSControlStateValueOn;
	BOOL oldState = [prefs showBorders];
	
	if (newState != oldState) {
		[prefs setShowBorders: newState];
		[prefs setShowGlkBorders: newState];
	}
}

- (IBAction) showCoverPictureChanged: (id) sender {
	BOOL newState = [sender state] == NSControlStateValueOn;
	BOOL oldState = [prefs showCoverPicture];
	
	if (newState != oldState) {
		[prefs setShowCoverPicture: newState];
	}	
}

- (IBAction) colourChanged: (id) sender {
	NSInteger newValue = [sender selectedTag];
	NSInteger oldValue = (sender==foregroundColour)?[prefs foregroundColour]:[prefs backgroundColour];
	
	if (newValue != oldValue) {
		if (sender == foregroundColour) {
			[prefs setForegroundColour: newValue];
		} else {
			[prefs setBackgroundColour: newValue];
		}
	}
}

@end
