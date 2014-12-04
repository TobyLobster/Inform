//
//  ZoomGlkSaveRef.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkSaveRef.h"
#import "ZoomSkein.h"
#import <GlkView/GlkFileRef.h>
#import <GlkView/GlkFileStream.h>

@implementation ZoomGlkSaveRef

// = Initialisation =

- (id) initWithPlugIn: (ZoomPlugIn*) newPlugin
				 path: (NSString*) newPath {
	self = [super init];
	
	if (self) {
		// Revert to being a standard GlkFileRef if the path doesn't end in .glksave (or it does and isn't a directory)
		BOOL isDir;
		if (![[NSFileManager defaultManager] fileExistsAtPath: newPath
												  isDirectory: &isDir]) {
			isDir = YES;
		}
			
		if (![[[newPath pathExtension] lowercaseString] isEqualToString: @"glksave"] || !isDir) {
			[self autorelease];
			return [[GlkFileRef alloc] initWithPath: path];
		}
		
		// Set up the plugin and path for this object
		plugin = [newPlugin retain];
		path = [newPath copy];
	}
	
	return self;
}

- (void) dealloc {
	[delegate release];
	[skein release];
	[preview release];
	[plugin release];
	[path release];
	
	[super dealloc];
}

// = Creating the glksave package =

- (BOOL) createSavePackage {
	// Constructs a save package at the specified path
	NSString* error;
	
	// Build the property list wrapper
	NSDictionary* saveProperties = [NSDictionary dictionaryWithObjectsAndKeys:
		[plugin gameFilename], @"ZoomGlkGameFileName",
		[[plugin idForStory] description], @"ZoomGlkGameId",
		[[plugin class] pluginDescription], @"ZoomGlkPluginDescription",
		[[plugin class] pluginAuthor], @"ZoomGlkPluginAuthor",
		[[plugin class] pluginVersion], @"ZoomGlkPluginVersion",
		nil];
	NSData* savePropertyList = [NSPropertyListSerialization dataFromPropertyList: saveProperties
																		  format: NSPropertyListXMLFormat_v1_0
																errorDescription: &error]; 
	if (error) {
		[error release];
		error = nil;
	}
	
	NSFileWrapper* savePropertyWrapper = [[[NSFileWrapper alloc] initRegularFileWithContents: savePropertyList] autorelease];
	[savePropertyWrapper setPreferredFilename: @"Info.plist"];
	
	// Build the save game file itself
	NSData* emptySaveGame = [NSData data];
	
	NSFileWrapper* saveGameWrapper = [[[NSFileWrapper alloc] initRegularFileWithContents: emptySaveGame] autorelease];
	[saveGameWrapper setPreferredFilename: @"Save.data"];
	
	// Build the skein data
	NSFileWrapper* skeinWrapper = nil;
	
	if (skein) {
		NSData* skeinData = [[skein xmlData] dataUsingEncoding: NSUTF8StringEncoding];
		if (skeinData) {
			skeinWrapper = [[[NSFileWrapper alloc] initRegularFileWithContents: skeinData] autorelease];
			[skeinWrapper setPreferredFilename: @"Skein.skein"];
		}
	}
	
	// Build the preview data
	NSFileWrapper* previewWrapper = nil;
	
	if (preview) {
		NSData* previewData = [NSPropertyListSerialization dataFromPropertyList: preview
																		 format: NSPropertyListXMLFormat_v1_0
															   errorDescription: &error];
		if (error) {
			[error release];
			error = nil;
		}
		
		if (previewData) {
			previewWrapper = [[[NSFileWrapper alloc] initRegularFileWithContents: previewData] autorelease];
			[previewWrapper setPreferredFilename: @"Preview.plist"];
		}
	}
	
	// Build the final save wrapper
	NSFileWrapper* saveWrapper = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:
		[NSDictionary dictionaryWithObjectsAndKeys:
			savePropertyWrapper, @"Info.plist",
			saveGameWrapper, @"Save.data",
			nil, nil]]
		autorelease];
	
	if (skeinWrapper) {
		[saveWrapper addFileWrapper: skeinWrapper];
	}
	if (previewWrapper) {
		[saveWrapper addFileWrapper: previewWrapper];
	}
	
	// Write it out
	if (![saveWrapper writeToFile: path
					   atomically: YES
				  updateFilenames: YES]) {
		return NO;
	}
	
	// Set the icon
	NSImage* iconImage = [plugin coverImage];
	if (iconImage && [[NSWorkspace sharedWorkspace] respondsToSelector: @selector(setIcon:forFile:options:)]) {
		NSImage* originalImage = [[NSWorkspace sharedWorkspace] iconForFileType: @"glksave"];
		NSImage* newImage = [[NSImage alloc] initWithSize: NSMakeSize(128, 128)];
		
		// Pick the 128x128 representation of the original
		NSEnumerator* originalImageRepEnum = [[originalImage representations] objectEnumerator];
		NSImageRep* rep;
		while (rep = [originalImageRepEnum nextObject]) {
			if ([rep size].width >= 128.0) break;
		}
		
		if (rep != nil) {
			originalImage = [[[NSImage alloc] init] autorelease];
			[originalImage addRepresentation: rep];
		}
		
		NSSize iconSize = [iconImage size];
		NSSize originalSize = [originalImage size];
		
		// Set the background for the image
		[newImage lockFocus];
		[[NSColor clearColor] set];
		NSRectFill(NSMakeRect(0,0,128,128));
		
		float scaleFactor;
		
		if (originalImage == nil || iconSize.width > 256 || iconSize.height > 256) {
			// Just use the cover image as the image for this save game
			scaleFactor = 128.0;
		} else {
			// Use a combined icon for this save game
			scaleFactor = 64.0;
			[originalImage drawInRect: NSMakeRect(0,0,128,128)
							 fromRect: NSMakeRect(0,0,originalSize.width,originalSize.height)
							operation: NSCompositeSourceOver
							 fraction: 1.0];
		}
		
		// Draw the icon on top
		if (iconSize.width > iconSize.height) {
			scaleFactor /= iconSize.width;
		} else {
			scaleFactor /= iconSize.height;
		}
		
		NSSize newSize = NSMakeSize(iconSize.width * scaleFactor, iconSize.height * scaleFactor);
		
		[iconImage drawInRect: NSMakeRect(64-newSize.width/2, 64-newSize.height/2, newSize.width, newSize.height)
					 fromRect: NSMakeRect(0,0, iconSize.width, iconSize.height)
					operation: NSCompositeSourceOver
					 fraction: 1.0];
		
		// Finish up
		[newImage unlockFocus];
		
		// Set the image for this save game
		[[NSWorkspace sharedWorkspace] setIcon: newImage
									   forFile: path
									   options: 0];
	}

	// Report success
	return YES;
}

// = Properties =

- (void) setDelegate: (id) newDelegate {
	[delegate release];
	delegate = [newDelegate retain];
}

- (void) setPreview: (NSArray*) newPreview {
	[preview release];
	preview = [[NSArray alloc] initWithArray: newPreview
								   copyItems: YES];
}

- (void) setSkein: (ZoomSkein*) newSkein {
	[skein release];
	skein = [newSkein retain];
}

- (ZoomSkein*) skein {
	return skein;
}
	
// = GlkFileRef implementation =

- (NSObject<GlkStream>*) createReadOnlyStream {
	// Load the skein from the path if it exists
	NSString* skeinPath = [path stringByAppendingPathComponent: @"Skein.skein"];
	if ([[NSFileManager defaultManager] fileExistsAtPath: skeinPath]) {
		if (!skein) skein = [[ZoomSkein alloc] init];
		
		[skein parseXmlData: [NSData dataWithContentsOfFile: skeinPath]];
	}
	
	// Inform the delegate we're about to start reading
	if (delegate && [delegate respondsToSelector: @selector(readingFromSaveFile:)]) {
		[delegate readingFromSaveFile: self];
	}
	
	// Create a read-only stream
	GlkFileStream* stream = [[GlkFileStream alloc] initForReadingWithFilename: [path stringByAppendingPathComponent: @"Save.data"]];
	
	return [stream autorelease];			
}

- (NSObject<GlkStream>*) createWriteOnlyStream {
	if ([self createSavePackage]) {
		GlkFileStream* stream = [[GlkFileStream alloc] initForWritingWithFilename: [path stringByAppendingPathComponent: @"Save.data"]];
		
		return [stream autorelease];		
	}
	
	// Couldn't (re)create the file
	return nil;
}

- (NSObject<GlkStream>*) createReadWriteStream {
	NSLog(@"WARNING: Save game files should not be opened read/write");
	
	// Try creating the savegame file
	if (![self createSavePackage]) {
		return nil;
	}
	
	// Construct a read/write stream
	GlkFileStream* stream = [[GlkFileStream alloc] initForReadWriteWithFilename: [path stringByAppendingPathComponent: @"Save.data"]];
	
	return [stream autorelease];			
}

- (void) deleteFile {
	[[NSFileManager defaultManager] removeFileAtPath: path 
											 handler: nil];	
}

- (BOOL) fileExists {
	return [[NSFileManager defaultManager] fileExistsAtPath: path];	
}

- (BOOL) autoflushStream {
	return autoflush;
}

- (void) setAutoflush: (BOOL) newAutoflush {
	autoflush = newAutoflush;
}

@end
