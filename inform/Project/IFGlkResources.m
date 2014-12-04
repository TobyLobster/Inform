//
//  IFGlkResources.m
//  Inform-xc2
//
//  Created by Andrew Hunter on 29/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFGlkResources.h"


@implementation IFGlkResources

- (id) initWithProject: (IFProject*) newProject {
	self = [super init];
	
	if (self) {
		project = [newProject retain];
	}
	
	return self;
}

- (void) dealloc {
	[project release];
	[manifest release];
	
	[super dealloc];
}

- (bycopy NSData*) dataForImageResource: (glui32) image {
	// Get the location of the image directory
	NSString* materials		= [project materialsPath];
	NSString* projectPath	= [[project fileURL] path];
	
	// Get the (default) location of the image file
	NSString* imageFile = [NSString stringWithFormat: @"Figure %i.png", image];
		
	// Load the manifest, if it exists
	if (manifest == nil) {
		// Try the project directory first
		NSString* manifestFile = [projectPath stringByAppendingPathComponent: @"manifest.plist"];
		
		// If there's no manifest in the project, look in the materials directory
		if (![[NSFileManager defaultManager] fileExistsAtPath: manifestFile]) {
			manifestFile = [materials stringByAppendingPathComponent: @"manifest.plist"];			
		}
		
		// Load the manifest file if it appears to exist
		if ([[NSFileManager defaultManager] fileExistsAtPath: manifestFile]) {
			manifest = [[NSDictionary dictionaryWithContentsOfFile: manifestFile] retain];
		}
		
		// If there's no manifest file, then use a blank one
		if (manifest == nil) {
			manifest = [[NSDictionary dictionary] retain];
		}
	}
	
	// Get the graphics manifest
	NSDictionary* graphics = [manifest objectForKey: @"Graphics"];
	
	// Get the image filename from the graphics manifest
	if (graphics != nil) {
		imageFile = [graphics objectForKey: [NSString stringWithFormat: @"%i", image]];
	}
	
	// Try to load the image
	NSString* imagePath = [materials stringByAppendingPathComponent: imageFile];
	if (imagePath != nil && [[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
		return [NSData dataWithContentsOfFile: imagePath];
	}
	
	// Return nothing
	return nil;
}

@end
