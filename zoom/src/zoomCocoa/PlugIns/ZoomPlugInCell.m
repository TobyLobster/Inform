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

#pragma mark - Initialisation

- (id) copyWithZone: (NSZone*) zone {
	ZoomPlugInCell* copy = [super copyWithZone: zone];
	copy->objectValue = objectValue;
	return copy;
}

#pragma mark - Drawing

- (void)drawInteriorWithFrame: (NSRect)cellFrame 
					   inView: (NSView *)controlView {
	// Cocoa doesn't seem able to deal with cells that aren't strings, numbers or dates, which is useless when we want to show plugin information
	// So, we instead set the value of this object to be an index into the plugin information array and then get the object from there
	// (instead of setting it directly to the object we want it to display, sigh).
	// More annoyingly, if you compile for debug, you can get around this, but Cocoa magics itself broken when
	// you compile for release.
	//
	// What's even MORE annoying is that even though the objectValue has an integer value, the intValue of this cell doesn't get set...
	NSInteger pos = [[self objectValue] integerValue];
	NSInteger count = [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] count];
	if (pos >= 0 && pos < count) {
		objectValue = [[[ZoomPlugInManager sharedPlugInManager] informationForPlugins] objectAtIndex: pos];		
	}
	
	// Load the image for this plugin
	NSImage* pluginImage = objectValue.image;
	
//	[pluginImage setCacheMode: NSImageCacheNever];
	
	// Draw the image for this plugin
	CGFloat drawHeight, drawWidth;
	
	if (pluginImage != nil) {
		NSSize imageSize = [pluginImage size];
		drawHeight = cellFrame.size.height - 4;
		drawWidth = imageSize.width * (drawHeight/imageSize.height);
		
		[pluginImage drawInRect: NSMakeRect(NSMinX(cellFrame) + 2, NSMinY(cellFrame)+2, drawWidth, drawHeight)
					   fromRect: NSZeroRect
					  operation: NSCompositingOperationSourceOver
					   fraction: 1.0
				 respectFlipped: YES
						  hints: nil];
	} else {
		drawWidth = drawHeight = cellFrame.size.height - 4;
	}
	
	if (drawWidth < drawHeight) drawWidth = drawHeight;
	
	// Decide on the fonts and colours to use
	NSColor* standardColour = [NSColor textColor];
	NSColor* infoColour = [NSColor secondaryLabelColor];
	NSColor* highlightColour = [NSColor systemRedColor];
	NSColor* highlightColour2 = [NSColor systemBlueColor];
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
			status = NSLocalizedStringFromTableInBundle(@"Update available", nil, [NSBundle bundleForClass:[self class]], @"Update available");
			if ([objectValue updateInfo] != nil) {
				status = [NSString stringWithFormat: NSLocalizedStringFromTableInBundle(@"Update available to v%@", nil, [NSBundle bundleForClass:[self class]], @"Update available to version value"), [[objectValue updateInfo] version]];
			}
			break;
			
			// Not yet installed, available to download
		case ZoomPlugInNew:
			status = NSLocalizedStringFromTableInBundle(@"New Plug-in", nil, [NSBundle bundleForClass:[self class]], @"New Plug-in");
			break;
			
			// Installed plugin, update to be installed
		case ZoomPlugInUpdated:
			status = NSLocalizedStringFromTableInBundle(@"Restart required", nil, [NSBundle bundleForClass:[self class]], @"Restart required");
			break;
			
			// Downloaded plugin available to install
		case ZoomPlugInDownloaded:
			status = NSLocalizedStringFromTableInBundle(@"Ready to install", nil, [NSBundle bundleForClass:[self class]], @"Ready to install");
			break;
			
			// Could not download the plugin for some reason
		case ZoomPlugInDownloadFailed:
			status = NSLocalizedStringFromTableInBundle(@"Could not download", nil, [NSBundle bundleForClass:[self class]], @"Could not download");
			break;

		case ZoomPlugInInstallFailed:
			status = NSLocalizedStringFromTableInBundle(@"Failed to install", nil, [NSBundle bundleForClass:[self class]], @"Failed to install");
			break;
			
		case ZoomPlugInDownloading:
			status = NSLocalizedStringFromTableInBundle(@"Downloading update", nil, [NSBundle bundleForClass:[self class]], @"Downloading update");
			break;
			
			// Installed plugin
		case ZoomPlugInInstalled:
			status = NSLocalizedStringFromTableInBundle(@"Installed plug-in", nil, [NSBundle bundleForClass:[self class]], @"Installed plug-in");
			break;
			
		case ZoomPlugInDisabled:
			status = NSLocalizedStringFromTableInBundle(@"Disabled plug-in", nil, [NSBundle bundleForClass:[self class]], @"Disabled plug-in");
			break;
			
		case ZoomPlugInNotKnown:									// Unknown status
		default:
			status = NSLocalizedStringFromTableInBundle(@"Unknown Plug Status", nil, [NSBundle bundleForClass:[self class]], @"Unknown Plug Status");
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
	NSString* result = [objectValue name];
	NSString *statusText = nil;
	
	switch ([objectValue status]) {
		case ZoomPlugInDisabled:
			statusText = NSLocalizedStringFromTableInBundle(@"Disabled plug-in", nil, [NSBundle bundleForClass:[self class]], @"Disabled plug-in");
			break;
		case ZoomPluginUpdateAvailable:
			statusText = NSLocalizedStringFromTableInBundle(@"Update available", nil, [NSBundle bundleForClass:[self class]], @"Update available");
			break;
		case ZoomPlugInNew:
			statusText = NSLocalizedStringFromTableInBundle(@"New Plug-in", nil, [NSBundle bundleForClass:[self class]], @"New Plug-in");
			break;
		case ZoomPlugInDownloadFailed:
			statusText = NSLocalizedStringFromTableInBundle(@"Download failed", nil, [NSBundle bundleForClass:[self class]], @"Download failed");
			break;
		case ZoomPlugInInstallFailed:
			statusText = NSLocalizedStringFromTableInBundle(@"Installation failed", nil, [NSBundle bundleForClass:[self class]], @"Installation failed");
			break;
		case ZoomPlugInDownloaded:
			statusText = NSLocalizedStringFromTableInBundle(@"Ready to install", nil, [NSBundle bundleForClass:[self class]], @"Ready to install");
			break;
		default:
			break;
	}
	if (statusText) {
		result = [NSString stringWithFormat:NSLocalizedStringWithDefaultValue(@"Plug-in Paren (%@, %@)", nil, [NSBundle bundleForClass:[self class]], @"%1$@ (%2$@)", @"Parantheses around status (#2) with name (#1)"), result, statusText];
	}
	
	return result;
}

- (NSString *)accessibilityRoleDescription
{
	return [self stringValue];
}

@end
