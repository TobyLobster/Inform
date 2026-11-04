//
//  IFGlkResources.m
//  Inform
//
//  Created by Andrew Hunter on 29/08/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import "IFGlkResources.h"
#import "IFProject.h"

@implementation IFGlkResources {
    IFProject* project;
    NSDictionary* manifest;
}

- (instancetype) initWithProject: (IFProject*) newProject {
	self = [super init];
	
	if (self) {
		project = newProject;
	}
	
	return self;
}


- (bycopy NSData*) dataForImageResource: (glui32) image {
	// Get the location of the image directory
	NSURL* materialsURL = project.materialsDirectoryURL;
	NSURL* projectURL	= project.fileURL;

	// Load the manifest, if it exists
	if (manifest == nil) {
		// Try the project directory first
		NSURL* manifestFileURL = [projectURL URLByAppendingPathComponent: @"manifest.plist"];

		// If there's no manifest in the project, look in the materials directory
		if (![[NSFileManager defaultManager] fileExistsAtPath: manifestFileURL.path]) {
			manifestFileURL = [materialsURL URLByAppendingPathComponent: @"manifest.plist"];
		}

		// Load the manifest file if it appears to exist
		manifest = [NSDictionary dictionaryWithContentsOfURL: manifestFileURL];

		// If there's no manifest file, then use a blank one
		if (manifest == nil) {
			manifest = @{};
		}
	}

	// Get the graphics manifest
	NSDictionary* graphics = manifest[@"Graphics"];

    // Get the (default) location of the image file
    NSString* imageFile = nil;

	// Get the image filename from the graphics manifest
	if (graphics != nil) {
		imageFile = graphics[[NSString stringWithFormat: @"%i", image]];
	}

    // Fallback
    if(imageFile == nil ) {
        imageFile = [NSString stringWithFormat: @"Figure %i.png", image];
    }

	// Try to load the image
	NSURL* imageURL = [materialsURL URLByAppendingPathComponent: imageFile];
	if (imageURL != nil && [[NSFileManager defaultManager] fileExistsAtPath: imageURL.path]) {
		return [NSData dataWithContentsOfURL: imageURL];
	}

    // Load the default image
    NSImage * defaultImage = [NSImage imageNamed:@"App/Interpreter/Error"];

    // Return NSData version
    return defaultImage.TIFFRepresentation;
}

@end
