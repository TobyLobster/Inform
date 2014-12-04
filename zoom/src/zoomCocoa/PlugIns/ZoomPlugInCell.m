//
//  ZoomPlugInCell.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomPlugInCell.h"
#import "ZoomPlugInManager.h"

@implementation ZoomPlugInCell

// = Initialisation =

- (void) dealloc {
	[objectValue release];
	[super dealloc];
}

- (id) copyWithZone: (NSZone*) zone {
	ZoomPlugInCell* copy = [super copyWithZone: zone];
	copy->objectValue = [objectValue retain];
	return copy;
}

// = Drawing =

- (void)drawInteriorWithFrame: (NSRect)cellFrame 
					   inView: (NSView *)controlView {
	// Cocoa doesn't seem able to deal with cells that aren't strings, numbers or dates, which is useless when we want to show plugin information
	// So, we instead set the value of this object to be an index into the plugin information array and then get the object from there
	// (instead of setting it directly to the object we want it to display, sigh).
	// More annoyingly, if you compile for debug, you can get around this, but Cocoa magics itself broken when
	// you compile for release.
	//
	// What's even MORE annoying is that even though the objectValue has an integer value, the intValue of this cell doesn't get set...
	int pos = [[self objectValue] intValue];
	int count = [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] count];
	if (pos >= 0 && pos < count) {
		[objectValue release];
		objectValue = [[[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] objectAtIndex: pos] retain];		
	}
	
	// Load the image for this plugin
	NSString* imageFile = [objectValue imagePath];
	NSImage* pluginImage = nil;
	if (imageFile != nil && [[NSFileManager defaultManager] fileExistsAtPath: imageFile]) {
		pluginImage = [[[NSImage alloc] initWithContentsOfFile: imageFile] autorelease];
	} else {
		pluginImage = [NSImage imageNamed: @"zoom-app"];
	}
	
	BOOL wasFlipped = [pluginImage isFlipped];
	[pluginImage setCacheMode: NSImageCacheNever];
	[pluginImage setFlipped: [controlView isFlipped]];
	
	// Draw the image for this plugin
	float drawHeight, drawWidth;
	
	if (pluginImage != nil) {
		NSSize imageSize = [pluginImage size];
		drawHeight = cellFrame.size.height - 4;
		drawWidth = imageSize.width * (drawHeight/imageSize.height);
		
		[pluginImage drawInRect: NSMakeRect(NSMinX(cellFrame) + 2, NSMinY(cellFrame)+2, drawWidth, drawHeight)
					   fromRect: NSMakeRect(0,0, imageSize.width, imageSize.height)
					  operation: NSCompositeSourceOver
					   fraction: 1.0];
	} else {
		drawWidth = drawHeight = cellFrame.size.height - 4;
	}
	
	if (drawWidth < drawHeight) drawWidth = drawHeight;
	
	[pluginImage setFlipped: wasFlipped];
	
	// Decide on the fonts and colours to use
	NSColor* standardColour = [NSColor blackColor];
	NSColor* infoColour = [NSColor grayColor];
	NSColor* highlightColour = [NSColor redColor];
	NSColor* highlightColour2 = [NSColor blueColor];
	if ([self isHighlighted]) {
		standardColour = [NSColor whiteColor];
		highlightColour = [NSColor whiteColor];
		highlightColour2 = [NSColor whiteColor];
		infoColour = [NSColor whiteColor];
	}

	NSFont* nameFont = [NSFont boldSystemFontOfSize: 13];
	NSFont* infoFont = [NSFont systemFontOfSize: 11];
	NSFont* statusFont = [NSFont boldSystemFontOfSize: 11];

	NSDictionary* infoAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
		infoFont, NSFontAttributeName,
		infoColour, NSForegroundColorAttributeName,
		nil];

	// Draw the name for this plugin
	[[objectValue name] drawAtPoint: NSMakePoint(NSMinX(cellFrame)+6+drawWidth, NSMinY(cellFrame)+2)
					 withAttributes: [NSDictionary dictionaryWithObjectsAndKeys: 
						 nameFont, NSFontAttributeName,
						 standardColour, NSForegroundColorAttributeName,
						 nil]];
	
	// Draw the author for this plugin
	NSString* authorName;
	if (![[objectValue author] isEqualToString: [objectValue interpreterAuthor]]) {
		authorName = [NSString stringWithFormat: @"%@ (%@)",
			[objectValue author], [objectValue interpreterAuthor]];
	} else {
		authorName = [NSString stringWithFormat: @"%@", [objectValue author]];
	}
	
	NSSize authorSize = [authorName sizeWithAttributes: infoAttributes];
	[authorName drawAtPoint: NSMakePoint(NSMinX(cellFrame)+6+drawWidth, NSMaxY(cellFrame)-2-authorSize.height)
			 withAttributes: infoAttributes];
	
	// Draw the version number of this plugin
	NSString* version = nil;
	
	if ([objectValue version] != nil) {
		if (version == nil) version = @"v";
		version = [version stringByAppendingFormat: @"%@", [objectValue version]];
	}
	if ([objectValue interpreterVersion] != nil) {
		if (version != nil) version = [version stringByAppendingString: @"/"];
		if (version == nil) version = @"v";
		version = [version stringByAppendingFormat: @"%@", [objectValue interpreterVersion]];
	}
	
	NSSize versionSize = [version sizeWithAttributes: infoAttributes];
	[version drawAtPoint: NSMakePoint(NSMaxX(cellFrame)-4-versionSize.width, NSMinY(cellFrame)+2)
		  withAttributes: infoAttributes];
	
	// Draw new, updated, installed, etc
	NSString* status = nil;
	NSDictionary* statusAttributes = nil;
	
	switch ([objectValue status]) {
		case ZoomPluginUpdateAvailable:								// Update available to download
		case ZoomPlugInNew:											// Not yet installed, available to download
		case ZoomPlugInDownloadFailed:
		case ZoomPlugInInstallFailed:
			statusAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				statusFont, NSFontAttributeName,
				highlightColour, NSForegroundColorAttributeName,
				nil];
			break;

		case ZoomPlugInUpdated:										// Installed plugin, update to be installed
		case ZoomPlugInDownloaded:									// Downloaded plugin available to install
		case ZoomPlugInDownloading:
		case ZoomPlugInDisabled:
			statusAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				statusFont, NSFontAttributeName,
				highlightColour2, NSForegroundColorAttributeName,
				nil];
			break;
			
		case ZoomPlugInInstalled:									// Installed plugin
		case ZoomPlugInNotKnown:									// Unknown status
		default:
			statusAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
				statusFont, NSFontAttributeName,
				infoColour, NSForegroundColorAttributeName,
				nil];
			break;
	}
	
	switch ([objectValue status]) {
		case ZoomPluginUpdateAvailable:								// Update available to download
			status = @"Update available";
			if ([objectValue updateInfo] != nil) {
				status = [NSString stringWithFormat: @"Update available to v%@", [[objectValue updateInfo] version]];
			}
			break;
			
		case ZoomPlugInNew:											// Not yet installed, available to download
			status = @"New";
			break;
			
		case ZoomPlugInUpdated:										// Installed plugin, update to be installed
			status = @"Restart required";
			break;
			
		case ZoomPlugInDownloaded:									// Downloaded plugin available to install
			status = @"Ready to install";
			break;
			
		case ZoomPlugInDownloadFailed:								// Could not download the plugin for some reason
			status = @"Could not download";
			break;

		case ZoomPlugInInstallFailed:
			status = @"Failed to install";
			break;
			
		case ZoomPlugInDownloading:
			status = @"Downloading update";
			break;
			
		case ZoomPlugInInstalled:									// Installed plugin
			status = @"Installed";
			break;
			
		case ZoomPlugInDisabled:
			status = @"Disabled";
			break;
			
		case ZoomPlugInNotKnown:									// Unknown status
		default:
			status = @"Error";
			break;
	}
	
	if (status != nil)
	{
		NSSize statusSize = [status sizeWithAttributes: statusAttributes];
		[status drawAtPoint: NSMakePoint(NSMaxX(cellFrame)-4-statusSize.width, NSMaxY(cellFrame)-2-statusSize.height)
			 withAttributes: statusAttributes];
	}
}

- (NSString*) stringValue {
	NSMutableString* result = [[[objectValue name] mutableCopy] autorelease];
	
	switch ([objectValue status]) {
		case ZoomPlugInDisabled:
			[result appendString: @" (Disabled)"];
			break;
		case ZoomPluginUpdateAvailable:
			[result appendString: @" (Update available)"];
			break;
		case ZoomPlugInNew:
			[result appendString: @" (New)"];
			break;
		case ZoomPlugInDownloadFailed:
			[result appendString: @" (Download failed)"];
			break;
		case ZoomPlugInInstallFailed:
			[result appendString: @" (Installation failed)"];
			break;
		case ZoomPlugInDownloaded:
			[result appendString: @" (Ready to install)"];
			break;
		default:
			break;
	}
	
	return result;
}

- (id)accessibilityAttributeValue:(NSString *)attribute {
	if ([attribute isEqualToString: NSAccessibilityRoleDescriptionAttribute]) {
		return [self stringValue];
	}
	
	return [super accessibilityAttributeValue: attribute];
}

@end
