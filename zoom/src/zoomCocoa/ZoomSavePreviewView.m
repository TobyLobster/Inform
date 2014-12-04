//
//  ZoomSavePreviewView.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Mon Mar 22 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomSavePreviewView.h"
#import "ZoomSavePreview.h"

#import "ZoomClient.h"
#import "ZoomAppDelegate.h"


@implementation ZoomSavePreviewView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		upperWindowViews = nil;
		[self setAutoresizesSubviews: YES];
		[self setAutoresizingMask: NSViewWidthSizable];
		selected = NSNotFound;
    }
    return self;
}

- (void) dealloc {
	if (upperWindowViews) [upperWindowViews release];
	
	[super dealloc];
}

- (void)drawRect:(NSRect)rect {
}

- (void) setDirectoryToUse: (NSString*) directory {
	// Get rid of our old views
	if (upperWindowViews) {
		[upperWindowViews makeObjectsPerformSelector: @selector(removeFromSuperview)];
		[upperWindowViews release];
		upperWindowViews = nil;
	}
	
	saveGamesAvailable = NO;
	upperWindowViews = [[NSMutableArray alloc] init];
	selected = NSNotFound;
	
	if (directory == nil || ![[NSFileManager defaultManager] fileExistsAtPath: directory]) {
		NSRect ourFrame = [self frame];
		ourFrame.size.height = 2;
		[self setFrame: ourFrame];
		[self setNeedsDisplay: YES];
		return;
	}
	
	// Get our frame size
	NSRect ourFrame = [self frame];
	ourFrame.size.height = 0;
	
	// Load all the zoomSave files from the given directory
	NSArray* contents = [[NSFileManager defaultManager] directoryContentsAtPath: directory];
	
	if (contents == nil) {
		return;
	}
	
	// Read in the previews from any .zoomSave packages
	NSEnumerator* fileEnum = [contents objectEnumerator];
	NSString* file;
	
	while (file = [fileEnum nextObject]) {
		if ([[[file pathExtension] lowercaseString] isEqualToString: @"zoomsave"]) {
			
			// This is a zoomSave file - load the preview
			NSString* previewFile = [directory stringByAppendingPathComponent: file];
			previewFile = [previewFile stringByAppendingPathComponent: @"ZoomPreview.dat"];
			
			BOOL isDir;
			
			if (![[NSFileManager defaultManager] fileExistsAtPath: previewFile
													  isDirectory: &isDir]) {
				// Can't be a valid zoomSave file
				continue;
			}
			
			if (isDir) {
				// Also can't be a valid zoomSave file
				continue;
			}
			
			// Presumably, this is a valid preview file...
			ZoomUpperWindow* win = [NSUnarchiver unarchiveObjectWithFile: previewFile];
			
			if (win != nil && ![win isKindOfClass: [ZoomUpperWindow class]]) continue;
			
			// We've got a valid window - add to the list of upper windows
			ZoomSavePreview* preview;
			
			preview = [[ZoomSavePreview alloc] initWithPreview: win
													  filename: previewFile];
			
			[preview setAutoresizingMask: NSViewWidthSizable];
			[preview setMenu: [self menu]];
			[self addSubview: preview];
			[upperWindowViews addObject: [preview autorelease]];
			
			saveGamesAvailable = YES;

		} else if ([[[file pathExtension] lowercaseString] isEqualToString: @"glksave"]) {
		
			// This is a glksave file
			NSString* previewFile = [directory stringByAppendingPathComponent: file];
			
			NSDictionary* previewProperties = nil;
			NSString* propertiesPath = [previewFile stringByAppendingPathComponent: @"Info.plist"];
			if ([[NSFileManager defaultManager] fileExistsAtPath: propertiesPath]) {
				previewProperties = [NSPropertyListSerialization propertyListFromData: [NSData dataWithContentsOfFile: propertiesPath]
																	 mutabilityOption: NSPropertyListImmutable
																			   format: nil
																	 errorDescription: nil];
				if (![previewProperties isKindOfClass: [NSDictionary class]]) previewProperties = nil;
			}
			
			if (!previewProperties) continue;
			
			ZoomStoryID* storyId = [[ZoomStoryID alloc] initWithIdString: [previewProperties objectForKey: @"ZoomGlkGameId"]];
			
			// Load the preview lines from the glksave directory
			NSArray* previewLines = nil;
			NSString* previewLinesPath = [previewFile stringByAppendingPathComponent: @"Preview.plist"];
			if ([[NSFileManager defaultManager] fileExistsAtPath: previewLinesPath]) {
				previewLines = [NSPropertyListSerialization propertyListFromData: [NSData dataWithContentsOfFile: previewLinesPath]
																mutabilityOption: NSPropertyListImmutable
																		  format: nil
																errorDescription: nil];
				if (![previewLines isKindOfClass: [NSArray class]]) previewLines = nil;
			}
			
			// Use some defaults if no lines are supplied
			if (!previewLines) {
				ZoomStory* story = [[NSApp delegate] findStory: storyId];
				
				if (story) {
					previewLines = [NSArray arrayWithObjects:
						[NSString stringWithFormat: @"Saved story from '%@'", [story title]],
						nil];
				} else {
					previewLines = [NSArray arrayWithObject: @"Saved story"];
				}
			}
			
			// Create the preview object
			ZoomSavePreview* preview = [[ZoomSavePreview alloc] initWithPreviewStrings: previewLines
																			  filename: propertiesPath];
			
			[preview setAutoresizingMask: NSViewWidthSizable];
			[preview setMenu: [self menu]];
			[self addSubview: preview];
			[upperWindowViews addObject: [preview autorelease]];
			
			saveGamesAvailable = YES;

		}
	}
	
	// Arrange the views, resize ourselves
	float size = 2;
	NSRect bounds = [self bounds];
	
	NSEnumerator* viewEnum = [upperWindowViews objectEnumerator];
	ZoomSavePreview* view;
	
	while (view = [viewEnum nextObject]) {
		[view setFrame: NSMakeRect(0, size, bounds.size.width, 48)];
		size += 49;
	}
	
	NSRect frame = [self frame];
	frame.size.height = size;
	
	[self setFrameSize: frame.size];
	[self setNeedsDisplay: YES];
}

- (BOOL) isFlipped {
	return YES;
}

- (void) mouseDown: (NSEvent*) event {
}

- (void) previewMouseUp: (NSEvent*) evt
				 inView: (ZoomSavePreview*) view {
	int clicked = [upperWindowViews indexOfObjectIdenticalTo: view];
	
	if (clicked == NSNotFound) {
		NSLog(@"BUG: save preview not found");
		return;
	}
	
	if ([evt clickCount] == 1) {
		// Select a new view
		if (selected != NSNotFound) {
			[[upperWindowViews objectAtIndex: selected] setHighlighted: NO];
		}
		
		[view setHighlighted: YES];
		selected = clicked;
	} else if ([evt clickCount] == 2) {
		// Launch this game
		NSString* filename = [view filename];
		NSString* directory = [filename stringByDeletingLastPathComponent];
		
		if ([[[directory pathExtension] lowercaseString] isEqualToString: @"glksave"]) {
			// Pass off to the app delegate
			[[NSApp delegate] application: NSApp
								 openFile: directory];
		} else {
			//ZoomClient* newDoc = 
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile: directory
																					display: YES];
		}
	}
}

- (NSString*) selectedSaveGame {
	if (selected >= 0 && selected != NSNotFound) {
		return [[upperWindowViews objectAtIndex: selected] filename];
	} else {
		return nil;
	}
}

- (BOOL) saveGamesAvailable {
	return saveGamesAvailable;
}

@end
