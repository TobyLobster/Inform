//
//  ZoomSavePreview.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Mar 27 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

// Yeah, ZoomSavePreview and ZoomSavePreviewView are confusing. Bah. And humbug!
// Maybe this would work better as a cell in an NSMatrix.

#import "ZoomSavePreview.h"
#import "ZoomSavePreviewView.h"

#import "ZoomStoryOrganiser.h"

@implementation ZoomSavePreview

static NSImage* saveHighlightInactive;
static NSImage* saveHighlightActive;
static NSImage* saveBackground;

+ (void) initialize {
	saveHighlightInactive = [[NSImage imageNamed: @"saveHighlightInactive"] retain];
	saveHighlightActive = [[NSImage imageNamed: @"saveHighlightActive"] retain];
	saveBackground = [[NSImage imageNamed: @"saveBackground"] retain];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		filename = nil;
		preview = nil;
		highlighted = NO;
    }
    return self;
}

- (id) initWithPreview: (ZoomUpperWindow*) prev
			  filename: (NSString*) file {
	self = [self init];
	
	if (self) {
		preview = [prev retain];
		filename = [file copy];
		highlighted = NO;
	}
	
	return self;
}

- (id) initWithPreviewStrings: (NSArray*) prev
					 filename: (NSString*) file {
	self = [self init];
	
	if (self) {
		previewLines = [prev retain];
		filename = [file copy];
		highlighted = NO;
	}
	
	return self;
}

- (void) dealloc {
	if (previewLines) [previewLines release];
	if (preview) [preview release];
	if (filename) [filename release];
	
	[super dealloc];
}

- (void) setHighlighted: (BOOL) value {
	highlighted = value;
	[self setNeedsDisplay: YES];
}

- (void)drawRect:(NSRect)rect {
	NSFont* lineFont = [NSFont systemFontOfSize: 9];
	NSFont* infoFont = [NSFont boldSystemFontOfSize: 11];
	
	NSRect ourBounds = [self bounds];
	
	// Background
	NSColor* textColour;
	NSColor* backgroundColour;
	
	if (highlighted) {
		if (saveHighlightActive) {
			backgroundColour = [NSColor colorWithPatternImage: saveHighlightActive];
			[[NSColor clearColor] set];
		} else {
			backgroundColour = [NSColor highlightColor];
			[[NSColor colorWithDeviceRed: .02 green: .39 blue: .80 alpha: 1.0] set];
		}
		
		textColour = [NSColor whiteColor];
	} else {
		if (saveBackground) {
			backgroundColour = [NSColor colorWithPatternImage: saveBackground];
		} else {
			backgroundColour = [NSColor whiteColor];
		}
		
		[[NSColor colorWithDeviceRed: .76 green: .76 blue: .76 alpha:1.0] set];
		textColour = [NSColor blackColor];
	}

	[[NSGraphicsContext currentContext] setPatternPhase: [self convertPoint: NSMakePoint(0,0)
																	 toView: nil]];
	
	[backgroundColour set];
	NSRectFill(rect);
	[NSBezierPath setDefaultLineWidth: 1.0];
	[NSBezierPath strokeRect: NSMakeRect(ourBounds.origin.x+0.5, ourBounds.origin.y+0.5, ourBounds.size.width-1.0, ourBounds.size.height-1.0)];
	
	// Preview lines (from the top)
	NSDictionary* previewStyle = [NSDictionary dictionaryWithObjectsAndKeys: 
		lineFont, NSFontAttributeName,
		textColour, NSForegroundColorAttributeName,
		backgroundColour, NSBackgroundColorAttributeName,
		nil];
	
	float ypos = 4;
	int lines = 0;
	
	NSArray* upperLines = nil;
	id thisLine;
	
	if (preview) {
		upperLines = [preview lines];
	} else if (previewLines) {
		upperLines = previewLines;
	}
	
	NSEnumerator* lineEnum = [upperLines objectEnumerator];
	
	while (thisLine = [lineEnum nextObject]) {
		// Strip any multiple spaces out of this line
		int x;
		
		unichar* newString = NULL;
		int newLen = 0;

		NSString* lineString;
		if ([thisLine isKindOfClass: [NSString class]]) {
			lineString = thisLine;
		} else {
			lineString = [thisLine string];
		}
		
		for (x=0; x<[thisLine length]; x++) {
			unichar chr = [lineString characterAtIndex: x];
			
			if (chr == 32) {
				while (x<[lineString length]-1 && [lineString characterAtIndex: x+1] == 32) {
					x++;
				}
			}
			
			newLen++;
			newString = realloc(newString, sizeof(unichar)*newLen);
			newString[newLen-1] = chr;
		}
		
		// Convert to NSString
		NSString* stripString = [[NSString alloc] initWithCharacters: newString
															  length: newLen];
		free(newString);
		
		// Draw this string
		NSSize stringSize = [stripString sizeWithAttributes: previewStyle];
		
		[stripString drawInRect: NSMakeRect(4, ypos, ourBounds.size.width-8, stringSize.height)
				withAttributes: previewStyle];
		ypos += stringSize.height;
		
		// Finish up
		[stripString release];
		
		lines++;
		if (lines > 2) break;
	}
	
	// Draw the filename
	NSDictionary* infoStyle = [NSDictionary dictionaryWithObjectsAndKeys: 
		infoFont, NSFontAttributeName,
		textColour, NSForegroundColorAttributeName,
		backgroundColour, NSBackgroundColorAttributeName,
		nil];
	
	NSString* displayName = [[filename stringByDeletingLastPathComponent] lastPathComponent];
	displayName = [displayName stringByDeletingPathExtension];
	
	NSSize infoSize = [displayName sizeWithAttributes: infoStyle];
	NSRect infoRect = ourBounds;
	
	infoRect.origin.x = 4;
	infoRect.origin.y = ourBounds.size.height - 4 - infoSize.height;
	infoRect.size.width -= 8;
	
	[displayName drawInRect: infoRect
			 withAttributes: infoStyle];
	
	// Draw the date (if there's room)
	infoRect.size.width -= infoSize.width + 4;
	infoRect.origin.x += infoSize.width + 4;
	
	NSDate* fileDate = [[[NSFileManager defaultManager] fileAttributesAtPath: filename
																traverseLink: YES] objectForKey: NSFileModificationDate];
	
	if (fileDate) {
		NSString* dateString = [[fileDate dateWithCalendarFormat: @"%d %b %Y %H:%M" timeZone: [NSTimeZone defaultTimeZone]] description];
		NSSize dateSize = [dateString sizeWithAttributes: infoStyle];
		
		if (dateSize.width <= infoRect.size.width) {
			infoRect.origin.x = (infoRect.origin.x + infoRect.size.width) - dateSize.width;
			infoRect.size.width = dateSize.width;
			
			[dateString drawInRect: infoRect
					withAttributes: infoStyle];
		}
	}
}

- (void) mouseDown: (NSEvent*) event {
}

- (void) mouseUp: (NSEvent*) event {
	ZoomSavePreviewView* superview = (ZoomSavePreviewView*)[self superview];
	
	if ([superview isKindOfClass: [ZoomSavePreviewView class]]) {
		// The superview has priority
		[superview previewMouseUp: event
						   inView: self];
	} else {
		[self setHighlighted: !highlighted];
	}
}

- (BOOL) isFlipped {
	return YES;
}

- (NSString*) filename {
	return filename;
}

- (IBAction) deleteSavegame: (id) sender {
	// Display a confirmation dialog
	NSBeginAlertSheet(@"Are you sure?", 
					  @"Delete", @"Keep", nil, nil, self, @selector(confirmDelete:returnCode:contextInfo:), 
					  nil, nil,
					  @"Are you sure you want to delete this saved game?");
	
	return;
}

- (void) confirmDelete:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	// Check the user confirmed the delete
	if (returnCode != NSAlertDefaultReturn) return;
	
	// Ensure that this is a genuine savegame
	BOOL genuine = YES;
	BOOL isDir = NO;
	NSString* reason = nil;
	
	NSString* saveDir = [[self filename] stringByDeletingLastPathComponent];
	
	if (![[[saveDir pathExtension] lowercaseString] isEqualToString: @"zoomsave"]
		&& ![[[saveDir pathExtension] lowercaseString] isEqualToString: @"glksave"]) {
		genuine = NO; reason = reason?reason:[NSString stringWithFormat: @"File has the wrong extension (%@)", [saveDir pathExtension]];
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath: saveDir
											  isDirectory: &isDir]) {
		genuine = NO; reason = reason?reason:@"File does not exist";
	}
	if (!isDir) {
		genuine = NO;  reason = reason?reason:@"File is not a directory";
	}
	
	NSString* saveQut = [saveDir stringByAppendingPathComponent: @"save.qut"];
	NSString* zPreview = [saveDir stringByAppendingPathComponent: @"ZoomPreview.dat"];
	NSString* status = [saveDir stringByAppendingPathComponent: @"ZoomStatus.dat"];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: saveQut
											  isDirectory: &isDir]) {
		genuine = NO; reason = reason?reason:@"Contents do not look like a saved game";
	}
	if (isDir) {
		genuine = NO; reason = reason?reason:@"Contents do not look like a saved game";
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath: zPreview
											  isDirectory: &isDir]) {
		genuine = NO; reason = reason?reason:@"Contents do not look like a saved game";
	}
	if (isDir) {
		genuine = NO; reason = reason?reason:@"Contents do not look like a saved game";
	}
	if (![[NSFileManager defaultManager] fileExistsAtPath: status
											  isDirectory: &isDir]) {
		genuine = NO; reason = reason?reason:@"Contents do not look like a saved game"; 
	}
	if (isDir) {
		genuine = NO; reason = reason?reason:@"Contents do not look like a saved game";
	}
	
	// Report a problem if not genuine
	if (!genuine) {
		NSBeginAlertSheet(@"Invalid save game", 
						  @"Cancel", nil, nil, nil, nil, nil, nil, nil,
						  @"This does not look like a valid Zoom save game - it's possible it has moved, or you've saved something that looks like a save game but isn't. %@.", reason);
		
		return;
	}
	
	// Delete the game
	[[NSFileManager defaultManager] removeFileAtPath: saveDir
											 handler: nil];
	
	// Force an update of the game window (bit of a hack, being lazy)
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomStoryOrganiserChangedNotification
														object: [ZoomStoryOrganiser sharedStoryOrganiser]];
}

- (IBAction) revealInFinder: (id) sender {
	NSString* dir = [[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
	BOOL isDir;
	
	if (![[NSFileManager defaultManager] fileExistsAtPath: dir
											  isDirectory: &isDir])
		return;
	if (!isDir)
		return;
	
	[[NSWorkspace sharedWorkspace] openFile: [[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent]];
}

@end
