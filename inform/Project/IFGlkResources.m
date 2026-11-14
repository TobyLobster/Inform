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


/// The file that a section of the project's manifest gives for a resource, relative to the materials directory
- (nullable NSString*) fileInManifestSection: (NSString*) section forResource: (glui32) resource {
	// Load the manifest, if it exists
	if (manifest == nil) {
		// Try the project directory first
		NSURL* manifestFileURL = [project.fileURL URLByAppendingPathComponent: @"manifest.plist"];

		// If there's no manifest in the project, look in the materials directory
		if (![[NSFileManager defaultManager] fileExistsAtPath: manifestFileURL.path]) {
			manifestFileURL = [project.materialsDirectoryURL URLByAppendingPathComponent: @"manifest.plist"];
		}

		// Load the manifest file if it appears to exist
		manifest = [NSDictionary dictionaryWithContentsOfURL: manifestFileURL];

		// If there's no manifest file, then use a blank one
		if (manifest == nil) {
			manifest = @{};
		}
	}

	// Get the filename from the section, which is ignored unless it's a dictionary of strings
	NSDictionary* files = manifest[section];
	if (![files isKindOfClass: [NSDictionary class]]) {
		return nil;
	}
	NSString* file = files[[NSString stringWithFormat: @"%u", resource]];
	if (![file isKindOfClass: [NSString class]]) {
		return nil;
	}
	return file;
}

- (bycopy NSData*) dataForImageResource: (glui32) image {
	// Get the location of the image directory
	NSURL* materialsURL = project.materialsDirectoryURL;

	// Get the image filename from the graphics manifest
	NSString* imageFile = [self fileInManifestSection: @"Graphics" forResource: image];

    // Fallback
    if(imageFile == nil ) {
        imageFile = [NSString stringWithFormat: @"Figure %u.png", image];
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

- (bycopy NSData*) dataForSoundResource: (glui32) sound {
	// Get the sound filename from the sounds manifest
	NSString* soundFile = [self fileInManifestSection: @"Sounds" forResource: sound];
	if (soundFile == nil) {
		return nil;
	}

	// Try to load the sound
	NSURL* soundURL = [project.materialsDirectoryURL URLByAppendingPathComponent: soundFile];
	if (soundURL == nil) {
		return nil;
	}
	return [NSData dataWithContentsOfURL: soundURL];
}

@end
