//
//  ZoomGlulxe.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/12/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "ZoomGlulxe.h"
#import <ZoomView/ZoomBlorbFile.h>
#import <ZoomView/ZoomPreferences.h>
#import <ZoomView/ZoomView-Swift.h>

@implementation ZoomGlulxe

+ (BOOL) canRunURL: (NSURL *)path {
	NSString* extn = [[path pathExtension] lowercaseString];
	
	// We can run .ulx files
	if ([extn isEqualToString: @"ulx"]) return YES;
	
	// ... and we can run blorb files with a Glulx block in them
	if ([extn isEqualToString: @"blb"] || [extn isEqualToString: @"glb"] || [extn isEqualToString: @"gblorb"] || [extn isEqualToString: @"zblorb"] || [extn isEqualToString: @"blorb"]) {
		if (![[NSFileManager defaultManager] fileExistsAtPath: path.path]) {
			// If no file exists at the path, then claim ownership of it
			return YES;
		}
		
		ZoomBlorbFile* blorb = [[ZoomBlorbFile alloc] initWithContentsOfURL: path
																	  error: NULL];
		
		if (blorb != nil && [blorb dataForChunkWithType: @"GLUL"] != nil) {
			return YES;
		}
	}
	
	return [super canRunURL: path];
}

+ (NSString*) pluginVersion {
	return [[NSBundle bundleForClass: [self class]] objectForInfoDictionaryKey: @"CFBundleVersion"];
}

+ (NSString*) pluginDescription {
	return @"Zoom Glulx PlugIn";
}

+ (NSString*) pluginAuthor {
	return @"Andrew Hunter";
}

- (id) initWithURL: (NSURL*) gameFile {
	// Initialise as usual
	self = [super initWithURL: gameFile];
	
	if (self) {
		// Work out which client to use
		NSString*			client = @"glulxe-client";
		ZoomPreferences*	zPrefs = [ZoomPreferences globalPreferences];
		
		switch ([zPrefs glulxInterpreter]) {
			case GlulxGit:		client = @"git-client"; break;
			case GlulxGlulxe:	client = @"glulxe-client"; break;
		}

		// Set the client to be glulxe
		[self setClientPath: [[NSBundle bundleForClass: [self class]] pathForAuxiliaryExecutable: client]];
	}
	
	return self;
}

#pragma mark - Metadata

- (ZoomStoryID*) idForStory {
	// Generate an MD5-based ID
	return [[ZoomStoryID alloc] initWithGlulxFileAtURL: [self gameURL]
												 error: NULL];
}

- (ZoomStory*) defaultMetadataWithError:(NSError *__autoreleasing *)outError {
	// Just use the default metadata-establishing routine
	return [ZoomStory defaultMetadataForURL: [self gameURL] error: outError];
}

- (NSImage*) coverImage {
	// Try decoding the cover picture, if available
	ZoomBlorbFile* decodedFile = [[ZoomBlorbFile alloc] initWithContentsOfURL: [self gameURL]
																		error: NULL];
	int coverPictureNumber = -1;
	
	// Try to retrieve the frontispiece tag (overrides metadata if present)
	NSData* front = [decodedFile dataForChunkWithType: @"Fspc"];
	if (front != nil && [front length] >= 4) {
		const unsigned char* fpc = [front bytes];
		
		coverPictureNumber = (((int)fpc[0])<<24)|(((int)fpc[1])<<16)|(((int)fpc[2])<<8)|(((int)fpc[3])<<0);
	}
	
	if (coverPictureNumber >= 0) {			
		// Attempt to retrieve the cover picture image
		if (decodedFile != nil) {
			NSData* coverPictureData = [decodedFile imageDataWithNumber: coverPictureNumber];
			
			if (coverPictureData) {
				NSImage* coverPicture = [[NSImage alloc] initWithData: coverPictureData];
				
				// Sometimes the image size and pixel size do not match up
				NSImageRep* coverRep = [[coverPicture representations] objectAtIndex: 0];
				NSSize pixSize = NSMakeSize([coverRep pixelsWide], [coverRep pixelsHigh]);
				
				if (!NSEqualSizes(pixSize, [coverPicture size])) {
					[coverPicture setSize: pixSize];
				}
				
				if (coverPicture != nil) {
					return coverPicture;
				}
			}
		}
	}
	
	// Default to the Glulxe icon
	return [NSImage imageNamed:@"GlkClient"];
}

- (NSImage*) logo {
	// Try decoding the cover picture, if available
	ZoomBlorbFile* decodedFile = [[ZoomBlorbFile alloc] initWithContentsOfURL: [self gameURL]
																		error: NULL];
	int coverPictureNumber = -1;
	
	// Try to retrieve the frontispiece tag (overrides metadata if present)
	NSData* front = [decodedFile dataForChunkWithType: @"Fspc"];
	if (front != nil && [front length] >= 4) {
		const unsigned char* fpc = [front bytes];
		
		coverPictureNumber = (((int)fpc[0])<<24)|(((int)fpc[1])<<16)|(((int)fpc[2])<<8)|(((int)fpc[3])<<0);
	}
	
	if (coverPictureNumber >= 0) {			
		// Attempt to retrieve the cover picture image
		if (decodedFile != nil) {
			NSData* coverPictureData = [decodedFile imageDataWithNumber: coverPictureNumber];
			
			if (coverPictureData) {
				NSImage* coverPicture = [[NSImage alloc] initWithData: coverPictureData];
				
				// Sometimes the image size and pixel size do not match up
				NSImageRep* coverRep = [[coverPicture representations] objectAtIndex: 0];
				NSSize pixSize = NSMakeSize([coverRep pixelsWide], [coverRep pixelsHigh]);
				
				if (!NSEqualSizes(pixSize, [coverPicture size])) {
					[coverPicture setSize: pixSize];
				}
				
				if (coverPicture != nil) {
					return [self resizeLogo: coverPicture];
				}
			}
		}
	}
	
	return nil;
}

@end
