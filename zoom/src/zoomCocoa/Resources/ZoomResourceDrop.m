//
//  ZoomResourceDrop.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Jul 28 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomResourceDrop.h"
#import "ZoomPreferences.h"
#import <ZoomView/ZoomView-Swift.h>
#import "ZoomBlorbFile.h"

static NSImage* needDropImage;
static NSImage* blorbImage;

@implementation ZoomResourceDrop

+ (void) initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		needDropImage = [NSImage imageNamed: @"NeedDrop"];
		blorbImage = [NSImage imageNamed: @"Blorb"];
	});
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
		droppedFilename = nil;
		
		[self registerForDraggedTypes: @[NSPasteboardTypeFileURL]];
		
		willOrganise = 2; // Take value from global preferences (default)
		enabled = YES;
    }
	
    return self;
}

- (void)drawRect:(NSRect)rect {
	if (!self.enabled) return;
	
	NSRect bounds = [self bounds];
	
	// Position to draw the image in
	NSRect imgRect = NSMakeRect(0,0,48,48);
	
	imgRect.origin.y = NSMaxY(bounds) - imgRect.size.height - 4;
	imgRect.origin.x = NSMinY(bounds) + (bounds.size.width - imgRect.size.width)/2.0;
	
	// Image and text to draw
	NSImage* img = nil;
	NSString* description;
	
	if (droppedFilename) {
		img = blorbImage;
		description = NSLocalizedString(@"Drag a Blorb resource file here to change the resources for this game", @"Drag a Blorb resource file here to change the resources for this game");
	} else {
		img = needDropImage;
		description = NSLocalizedString(@"Drag a Blorb resource file here to set it as the graphics/sound resources for this game", @"Drag a Blorb resource file here to set it as the graphics/sound resources for this game");
	}
	
	// Draw the image
	[img drawInRect: imgRect
		   fromRect: NSZeroRect
		  operation: NSCompositingOperationSourceOver
		   fraction: 1.0];
	
	// Draw the text
	NSRect remainingRect = bounds;
	NSMutableParagraphStyle* paraStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paraStyle setAlignment: NSTextAlignmentCenter];
	
	remainingRect.size.height -= imgRect.size.height + 8;
	
	[description drawInRect: remainingRect
			 withAttributes: @{
		NSFontAttributeName:[NSFont systemFontOfSize: 11],
		NSParagraphStyleAttributeName: paraStyle,
		NSForegroundColorAttributeName: NSColor.textColor
	}];
}

- (void) setWillOrganise: (BOOL) wO {
	willOrganise = wO?1:0;
}

- (BOOL) willOrganise {
	if (willOrganise == 1) {
		return YES;
	} else if (willOrganise == 0) {
		return NO;
	} else {
		return [[ZoomPreferences globalPreferences] keepGamesOrganised];
	}
}

- (void) setEnabled: (BOOL) en {
	if (en != enabled) {
		enabled = en;
		[self setNeedsDisplay: YES];
	}
}

@synthesize enabled;
@synthesize droppedFilename;

#pragma mark - NSDraggingDestination methods

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
	if (!enabled) return NSDragOperationNone;
	
	if ([self willOrganise]) {
		return NSDragOperationCopy;
	} else {
		if ([[sender draggingPasteboard] readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}] == nil) return NSDragOperationNone;
		return NSDragOperationLink;
	}
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender {
	if (!enabled) return NO;

	if (![self willOrganise] && ([sender draggingSourceOperationMask]&NSDragOperationLink)==0) {
		// Must be able to link if we're not organising
		return NO;
	}
		
	NSArray<NSURL*>* filenames = [[sender draggingPasteboard] readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	if (filenames != nil && [filenames isKindOfClass: [NSArray class]]) {
		// Is a filename array: we can handle one filename, which must be a .blb, .glb or .zlb file
		if ([filenames count] != 1) goto notAFilename;
		
		NSURL* filename = [filenames objectAtIndex: 0];
		if (![filename isKindOfClass: [NSURL class]]) goto notAFilename;
		
		if (!([[filename pathExtension] isEqualToString: @"blb"] || 
			  [[filename pathExtension] isEqualToString: @"zlb"] ||
			  [[filename pathExtension] isEqualToString: @"glb"] ||
			  [[filename pathExtension] isEqualToString: @"zblorb"] ||
			  [ZoomBlorbFile URLContentsAreBlorb: filename])) {
			// MAYBE IMPLEMENT ME: check if this is a blorb file anyway (look for an IFRS file?)
			goto notAFilename;
		}
		
		return YES;
	}
	
notAFilename:
	// Deal with the other types - can't link to these
	if (([sender draggingSourceOperationMask]&NSDragOperationCopy) == 0) return NO;
			
	// Default is to reject: require filenames for the moment
	return NO;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
	if (![self willOrganise] && ([sender draggingSourceOperationMask]&NSDragOperationLink)==0) {
		// Must be able to link if we're not organising
		return NO;
	}
	
	NSArray<NSURL*>* filenames = [[sender draggingPasteboard] readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	if (filenames != nil && [filenames isKindOfClass: [NSArray class]]) {
		// Is a filename array: we can handle one filename, which must be a .blb, .glb or .zlb file
		if ([filenames count] != 1) return NO;
		
		NSString* filename = [filenames objectAtIndex: 0].path;
		if (![filename isKindOfClass: [NSString class]]) return NO;
		
		if (!([[filename pathExtension] isEqualToString: @"blb"] || 
			  [[filename pathExtension] isEqualToString: @"zlb"] ||
			  [[filename pathExtension] isEqualToString: @"glb"])) {
			// MAYBE IMPLEMENT ME: check if this is a blorb file anyway (look for an IFRS file?)
			return NO;
		}
		
		if (droppedData != nil) {
			droppedData = nil;
			[self resourceDropDataChanged: self];
		}
		
		droppedFilename = [filename copy];
		[self resourceDropFilenameChanged: self];
		[self setNeedsDisplay: YES];
		
		return YES;
	} else {
		// Deal with the other types - can't link to these
		if (([sender draggingSourceOperationMask]&NSDragOperationCopy) == 0) return NO;
		
		return NO; // Anyway - FIXME
	}
	
	return NO;
}

// Delegate
@synthesize delegate;

- (void) resourceDropFilenameChanged: (ZoomResourceDrop*) drop {
	if ([delegate respondsToSelector: @selector(resourceDropFilenameChanged:)]) {
		[delegate resourceDropFilenameChanged: drop];
	}
	
	NSLog(@"Resource drop filename changed... Checking:");
	NSError *err;
	ZoomBlorbFile* file = [[ZoomBlorbFile alloc] initWithContentsOfURL: [NSURL fileURLWithPath: droppedFilename]
																 error: &err];
	if (file == nil) {
		NSLog(@"Failed to load file: %@", err.localizedDescription);
		return;
	}
	
	if (![file parseResourceIndex]) {
		NSLog(@"Failed to parse index");
	}
}

- (void) resourceDropDataChanged: (ZoomResourceDrop*) drop {
	if ([delegate respondsToSelector: @selector(resourceDropDataChanged:)]) {
		[delegate resourceDropDataChanged: drop];
	}
}

@end
