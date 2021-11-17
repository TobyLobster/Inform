#import "ZoomGameInfoController.h"
#import "ZoomPreferences.h"

@interface UnknownSelectors: NSObject
- (IBAction)infoGenreChanged:(id)sender;
- (IBAction)infoCommentsChanged:(id)sender;
- (IBAction)infoMyRatingChanged:(id)sender;
- (IBAction)infoTeaserChanged:(id)sender;
- (IBAction)infoResourceChanged:(id)sender;
@end

@implementation ZoomGameInfoController

#pragma mark - Shared info controller
+ (ZoomGameInfoController*) sharedGameInfoController {
	static ZoomGameInfoController* shared = NULL;
	
	if (shared == NULL) {
		shared = [[ZoomGameInfoController alloc] init];
	}
	
	return shared;
}

#pragma mark - Initialisation/finalisation

- (id) init {
	self = [self initWithWindowNibPath: [[NSBundle bundleForClass: [ZoomGameInfoController class]] pathForResource: @"GameInfo"
																											 ofType: @"nib"]
								 owner: self];
	
	if (self) {
		gameInfo = nil;
	}
	
	return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
}

#pragma mark - Owner

@synthesize infoOwner;

#pragma mark - Interface actions

- (IBAction)selectGenre:(id)sender {
	NSString* name = nil;
	switch ([sender tag]) {
		case 0: name = @"Fantasy"; break;
		case 1: name = @"Science fiction"; break;
		case 2: name = @"Horror"; break;
		case 3: name = @"Fairy tale"; break;
		case 4: name = @"Surreal"; break;
		case 5: name = @"Mystery"; break;
		case 6: name = @"Romance"; break;
		case 7: name = @"Historical"; break;
		case 8: name = @"Humour"; break;
		case 9: name = @"Parody"; break;
		case 10: name = @"Speed-IF"; break;
		case 11: name = @"Arcade"; break;
		case 12: name = @"Interpreter abuse"; break;
		case 13: name = @"Contemporary fiction"; break;
	}
	
	if (name) {
		[genre setStringValue: name];
	}
	
	[NSApp sendAction: @selector(infoGenreChanged:)
				   to: nil 
				 from: self];
}

- (IBAction)showGenreMenu:(id)sender {
	[NSMenu popUpContextMenu: genreMenu
				   withEvent: [NSApp currentEvent]
					 forView: [[self window] contentView]];
}

- (IBAction)activateRating:(id)sender {
	if ([ratingOn state] == NSControlStateValueOn) {
		[rating setEnabled: YES];
	} else {
		[rating setEnabled: NO];
	}
	
	[NSApp sendAction: @selector(infoMyRatingChanged:)
				   to: nil 
				 from: self];
}

static NSString* stringOrEmpty(NSString* str) {
	if (str == nil)
		return @"";
	else
		return str;
}

- (void) setGameInfo: (ZoomStory*) info {
	[self window]; // (Make sure the window is loaded)
	
	if (info == nil) {
		gameInfo = nil;
		
		[gameName setEnabled: NO];		[gameName setStringValue: @"No game selected"];
		[headline setEnabled: NO];		[headline setStringValue: @""];
		[author setEnabled: NO];		[author setStringValue: @""];
		[genre setEnabled: NO];			[genre setStringValue: @""];
		[year setEnabled: NO];			[year setStringValue: @""];
		[group setEnabled: NO];			[group setStringValue: @""];
		
		[comments setEditable: NO];		[comments setString: @""];
		[teaser setEditable: NO];		[teaser setString: @""];
		
		[zarfRating setEnabled: NO];	[zarfRating selectItemAtIndex: 0];
		[rating setEnabled: NO];		[rating setIntValue: 5.0];
		[ratingOn setEnabled: NO];		[ratingOn setState: NSControlStateValueOff];
		
		[resourceDrop setEnabled: NO]; [chooseResourceButton setEnabled: NO];
	} else {		
		gameInfo = info;

		[gameName setEnabled: YES];		[gameName setStringValue: stringOrEmpty([info title])];
		[headline setEnabled: YES];		[headline setStringValue: stringOrEmpty([info headline])];
		[author setEnabled: YES];		[author setStringValue: stringOrEmpty([info author])];
		[genre setEnabled: YES];		[genre setStringValue: stringOrEmpty([info genre])];
		[year setEnabled: YES];			
		
		int yr = [info year];
		if (yr > 0) {
			[year setStringValue: [NSString stringWithFormat: @"%i", yr]];
		} else {
			[year setStringValue: @""];
		}
		
		[group setEnabled: YES];		[group setStringValue: stringOrEmpty([info group])];
		[comments setEditable: YES];	[comments setString: stringOrEmpty([info comment])];
		[teaser setEditable: YES];		[teaser setString: stringOrEmpty([info teaser])];
		
		[zarfRating setEnabled: YES];   [zarfRating selectItemAtIndex: [info zarfian]];
		
		float rat = [info rating];
		if (rat >= 0) {
			[rating setEnabled: YES];		[rating setIntValue: rat];
			[ratingOn setEnabled: YES];		[ratingOn setState: NSControlStateValueOn];
		} else {
			[rating setEnabled: NO];		[rating setIntValue: 5.0];
			[ratingOn setEnabled: YES];		[ratingOn setState: NSControlStateValueOff];
		}
		
		// FIXME: need improved metadata handling to implement this properly
		NSString *resfilnam = [info objectForKey: @"ResourceFilename"];
		[resourceDrop setDroppedFilename: resfilnam];
		if (resfilnam) {
			resourceFilenameField.stringValue = resfilnam;
		} else {
			resourceFilenameField.stringValue = @"";
		}
		[resourceDrop setEnabled: YES]; [chooseResourceButton setEnabled: YES];
	}
}

@synthesize gameInfo;

// Reading the current (updated) contents of the game info window
- (NSString*) title {
	return [gameName stringValue];
}

- (NSString*) headline {
	return [headline stringValue];
}

- (NSString*) author {
	return [author stringValue];
}

- (NSString*) genre {
	return [genre stringValue];
}

- (int) year {
	return [year intValue];
}

- (NSString*) group {
	return [group stringValue];
}

- (NSString*) comments {
	return [comments string];
}

- (NSString*) teaser {
	return [teaser string];
}

- (IFMB_Zarfian) zarfRating {
	return (IFMB_Zarfian)[zarfRating indexOfSelectedItem];
}

- (float) rating {
	if ([ratingOn state] == NSControlStateValueOn) {
		return [rating floatValue];
	} else {
		return -1;
	}
}

- (NSDictionary*) dictionary {
	return @{@"title": [self title],
			 @"headline": [self headline],
			 @"author": [self author],
			 @"genre": [self genre],
			 @"year": @([self year]),
			 @"group": [self group],
			 @"comments": [self comments],
			 @"teaser": [self teaser],
			 @"zarfRating": @([self zarfRating]),
			 @"rating": @([self rating])};
}

#pragma mark - NSText delegate

- (void)textDidEndEditing:(NSNotification *)aNotification {
	NSTextView* textView = [aNotification object];
	
	if (textView == comments) {
		[NSApp sendAction: @selector(infoCommentsChanged:)
					   to: nil
					 from: self];
	} else if (textView == teaser) {
		[NSApp sendAction: @selector(infoTeaserChanged:)
					   to: nil
					 from: self];
	} else {
		NSLog(@"Unknown text view");
	}
}

#pragma mark - Resource files

- (NSString*) resourceFilename {
	return [resourceDrop droppedFilename];
}

- (void) setResourceFile: (NSString*) filename {
	[resourceDrop setDroppedFilename: filename];
	[resourceDrop setNeedsDisplay: YES];
	resourceFilenameField.stringValue = filename;
	[NSApp sendAction: @selector(infoResourceChanged:)
				   to: nil
				 from: self];
}

- (IBAction)chooseResourceFile:(id)sender {
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	NSArray* filetypes = @[@"blb", @"blorb"];
	
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseDirectories: NO];
	[openPanel setCanChooseFiles: YES];
	[openPanel setDelegate: self];
	openPanel.allowedFileTypes = filetypes;
	
	NSString* directory = nil;
	if ([self resourceFilename] != nil) {
		directory = [[self resourceFilename] stringByDeletingLastPathComponent];
	}
	
	if (directory) {
		openPanel.directoryURL = [NSURL fileURLWithPath:directory];
	}
	
	[openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
		if (result != NSModalResponseOK) return;
		
		[self setResourceFile: [[openPanel URL] path]];
	}];
}

- (void) resourceDropFilenameChanged: (ZoomResourceDrop*) drop {
	[self setResourceFile: [drop droppedFilename]];
}

@end
