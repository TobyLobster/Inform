#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "ZoomSkein.h"
#import "ZoomMetadata.h"
#import "ZoomBabel.h"

#pragma GCC visibility push(hidden)

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

static NSString* zoomConfigDirectory() {
	NSArray* libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
	
	for (NSString* libDir in libraryDirs) {
		BOOL isDir;
		
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: zoomLib isDirectory: &isDir]) {
			if (isDir) {
				return zoomLib;
			}
		}
	}
	
	for (NSString* libDir in libraryDirs) {
		NSString* zoomLib = [[libDir stringByAppendingPathComponent: @"Preferences"] stringByAppendingPathComponent: @"uk.org.logicalshift.zoom"];
		if ([[NSFileManager defaultManager] createDirectoryAtPath: zoomLib
									  withIntermediateDirectories: NO
													   attributes: nil
															error: NULL]) {
			return zoomLib;
		}
	}
	
	return nil;
}

OSStatus GeneratePreviewForBabel(void *thisInterface, 
								 QLPreviewRequestRef preview,
								 CFURLRef cfUrl, 
								 CFStringRef contentTypeUTI, 
								 CFDictionaryRef options) {
	// Can't deal with file URLs.
	NSURL* url = (__bridge NSURL*)cfUrl;
	if (![url isFileURL]) return noErr;
	
	// Get the metadata for the story
	ZoomBabel* babel = [[ZoomBabel alloc] initWithFilename: [url path]];
	ZoomStory* story = [babel metadata];
	ZoomStoryID* storyID = [story storyID];
	NSImage* image = [babel coverImage];
	
	if (image == nil) {
		// If there's no image, then we need to use a default one
		image = [[NSBundle bundleWithIdentifier: @"uk.org.logicalshift.zoom.save.quicklook"] imageForResource:@"zoom-game"];
	}

	// Try to use babel to work out the story ID, if we have no metadata
	if (!story || !storyID) {
		storyID = [babel storyID];
	}
	
	// Give up if the ID is still nil
	if (storyID == nil) {
		return noErr;
	}
	
	// Try to load Zoom's built-in metadata if we can
	ZoomMetadata* metadata = nil;
	NSData* userData = [NSData dataWithContentsOfFile: [zoomConfigDirectory() stringByAppendingPathComponent: @"metadata.iFiction"]];
	if (userData) metadata = [[ZoomMetadata alloc] initWithData: userData error: NULL];
	
	if (metadata) {
		story = [metadata containsStoryWithIdent: storyID]?[metadata findOrCreateStory: storyID]:story;
	}
	
	// If there's no metadata returned, then give up
	if (story == nil) return noErr;
	
	// Generate an attributed string describing the story
	NSFont* titleFont		= [NSFont boldSystemFontOfSize: 24];
	NSFont* descriptionFont	= [NSFont systemFontOfSize: 11];
	NSFont* smallFont		= [NSFont systemFontOfSize: 10];
	NSFont* ifidFont		= [NSFont boldSystemFontOfSize: 9];
	NSColor* foreground		= [NSColor whiteColor];
	NSColor* background		= [NSColor clearColor];
	
	NSDictionary* titleAttr	= [NSDictionary dictionaryWithObjectsAndKeys:
							   titleFont, NSFontAttributeName,
							   foreground, NSForegroundColorAttributeName,
							   background, NSBackgroundColorAttributeName,
							   nil];
	NSDictionary* smallAttr	= [NSDictionary dictionaryWithObjectsAndKeys:
							   smallFont, NSFontAttributeName,
							   foreground, NSForegroundColorAttributeName,
							   background, NSBackgroundColorAttributeName,
							   nil];
	NSDictionary* ifidAttr	= [NSDictionary dictionaryWithObjectsAndKeys:
							   ifidFont, NSFontAttributeName,
							   foreground, NSForegroundColorAttributeName,
							   background, NSBackgroundColorAttributeName,
							   nil];
	NSDictionary* descrAttr	= [NSDictionary dictionaryWithObjectsAndKeys:
							   descriptionFont, NSFontAttributeName,
							   foreground, NSForegroundColorAttributeName,
							   background, NSBackgroundColorAttributeName,
							   nil];
	
	NSMutableAttributedString* description = [[NSMutableAttributedString alloc] init];
	
	if ([story title]) {
		[description appendAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"%@\n", [story title]]
																			  attributes: titleAttr]];
	}
	[description appendAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"IFID: %@\n", [storyID description]]
																		  attributes: ifidAttr]];
	if ([story author] && [[story author] length] > 0) {
		NSString* publication = @"";
		if ([story year] > 0) {
			publication = [NSString stringWithFormat: @", published %i", [story year]];
		}
		[description appendAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"by %@%@\n", [story author], publication]
																			  attributes: smallAttr]];
	}
	
	if ([story description] && [[story description] length] > 0) {
		[description appendAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"\n%@", [story description]]
																			  attributes: descrAttr]];
	} else if ([story teaser] && [[story teaser] length] > 0) {
		[description appendAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"\n%@", [story teaser]]
																			  attributes: descrAttr]];
	}
	
	// Decide on the size of the graphics context
	CGSize previewSize;
	previewSize.width = 760;
	previewSize.height = 320;

	NSRect descriptionRect = [description boundingRectWithSize: NSMakeSize((previewSize.width - previewSize.height) - 16, 1e8)
													   options: 0];
	
	if (image != nil) {
		previewSize.height = [image size].height;
		
		if (previewSize.height < 180) previewSize.height = 180;
		if (previewSize.height < descriptionRect.size.height + 32) previewSize.height = descriptionRect.size.height + 32;
		if (previewSize.height > 320) previewSize.height = 320;
		
		previewSize.width *= previewSize.height / 320.0;
		if (previewSize.width < 560) previewSize.width = 560;
	}
	
	// Create a graphics context to draw into
	CGContextRef cgContext = QLPreviewRequestCreateContext(preview, previewSize,
														 false, NULL);
	
	NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithCGContext: cgContext
																		 flipped: NO];
	
	// Start drawing
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext: context];
	[context setImageInterpolation: NSImageInterpolationHigh];
	
	// Draw the image
	NSRect imageRect = NSMakeRect(8,8, 0,0);
	if (image) {
		NSSize imageSize = [image size];
		imageRect = NSMakeRect(8,8, previewSize.height - 16, previewSize.height - 16);
		CGFloat ratio = imageSize.height / imageSize.width;
		if (ratio < 1) {
			imageRect.size.height *= ratio;			
		} else {
			double oldWidth = imageRect.size.width;
			imageRect.size.width /= ratio;
		}
		
		[image drawInRect: imageRect
				 fromRect: NSZeroRect
				operation: NSCompositingOperationSourceOver
				 fraction: 1.0];
	}
	
	// Draw the description
	NSRect descRect = NSMakeRect(imageRect.size.width + 24, 8, (previewSize.width - previewSize.height) - 16, previewSize.height - 16);
	[description drawInRect: descRect];
	
	// Done with the drawing
	[NSGraphicsContext restoreGraphicsState];
	
	// Finish up with the context
	QLPreviewRequestFlushContext(preview, cgContext);
	CFRelease(cgContext);
	
	return noErr;
}

OSStatus GeneratePreviewForURL(void *thisInterface, 
							   QLPreviewRequestRef preview,
							   CFURLRef cfUrl, 
							   CFStringRef contentTypeUTI, 
							   CFDictionaryRef options)
{
	@autoreleasepool {
	NSURL* url = (__bridge NSURL*)cfUrl;
	NSData* skeinData = nil;
	ZoomSkein* skein = nil;
	ZoomStoryID* storyID = nil;
	
	// Read the data for this file
	if ([(__bridge NSString*)contentTypeUTI isEqualToString: @"uk.org.logicalshift.zoomsave"]) {
		// .zoomsave package
		
		// Read in the skein
		NSURL* skeinUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Skein.skein"]];
		skeinData = [NSData dataWithContentsOfURL: skeinUrl];
		
		// Work out the story ID
		NSURL* plistUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Info.plist"]];
		NSData* plist = [NSData dataWithContentsOfURL: plistUrl];
		
		if (plist != nil) {
			NSDictionary* plistDict = [NSPropertyListSerialization propertyListWithData: plist
																				options: NSPropertyListImmutable
																				 format: nil
																				  error: nil];
			NSString* idString  = [plistDict objectForKey: @"ZoomStoryId"];
			if (idString != nil) {
				storyID = [[ZoomStoryID alloc] initWithIdString: idString];
			}
		}
		
	} else if ([(__bridge NSString*)contentTypeUTI isEqualToString: @"uk.org.logicalshift.glksave"]) {
		// .glksave package
		
		// Read in the skein
		NSURL* skeinUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Skein.skein"]];
		skeinData = [NSData dataWithContentsOfURL: skeinUrl];

		
		// Work out the story ID
		NSURL* plistUrl = [NSURL URLWithString: [[url absoluteString] stringByAppendingString: @"/Info.plist"]];
		NSData* plist = [NSData dataWithContentsOfURL: plistUrl];
		
		if (plist != nil) {
			NSDictionary* plistDict = [NSPropertyListSerialization propertyListWithData: plist
																				options: NSPropertyListImmutable
																				 format: nil
																				  error: nil];
			NSString* idString  = [plistDict objectForKey: @"ZoomGlkGameId"];
			if (idString != nil) {
				storyID = [[ZoomStoryID alloc] initWithIdString: idString];
			}
		}
	} else {
		
		// Generate a babel preview
		return GeneratePreviewForBabel(thisInterface, preview, cfUrl, contentTypeUTI, options);

	}
	
	// Try to parse the skein
	if (skeinData) {
		skein = [[ZoomSkein alloc] init];
		if (![skein parseXmlData: skeinData error: NULL]) {
			skein = nil;
		}
	}
	
	// If we've got a skein, then generate an attributed string to represent the transcript of play
	if (skein && [skein activeItem]) {
		NSMutableAttributedString* result = [[NSMutableAttributedString alloc] init];
		ZoomSkeinItem* activeItem = [skein activeItem];
		
		// Set up the attributes for the fonts
		NSFont* transcriptFont = [[NSFontManager sharedFontManager] fontWithFamily: @"Gill Sans"
																			traits: NSUnboldFontMask
																			weight: 5
																			  size: 12];
		NSFont* inputFont = [[NSFontManager sharedFontManager] fontWithFamily: @"Gill Sans"
																	   traits: NSBoldFontMask
																	   weight: 9
																	     size: 12];
		NSFont* titleFont = [[NSFontManager sharedFontManager] fontWithFamily: @"Gill Sans"
																	   traits: NSBoldFontMask
																	   weight: 9
																	     size: 18];
		if (!transcriptFont) transcriptFont = [NSFont systemFontOfSize: 12];
		if (!inputFont) inputFont = [NSFont systemFontOfSize: 12];
		if (!titleFont) titleFont = [NSFont boldSystemFontOfSize: 12];
		
		NSDictionary* transcriptAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
											  transcriptFont, NSFontAttributeName,
											  nil];
		NSDictionary* inputAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
										 inputFont, NSFontAttributeName,
										 nil];
		NSDictionary* titleAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
										 titleFont, NSFontAttributeName,
										 nil];
		NSAttributedString* newline = [[NSAttributedString alloc] initWithString: @"\n"
																	  attributes: transcriptAttributes];
		
		// Build the transcript
		while (activeItem != nil) {
			// Append this string
			NSAttributedString* inputString = nil;
			NSAttributedString* responseString = nil;
			
			if ([activeItem command]) {
				inputString = [[NSAttributedString alloc] initWithString: [activeItem command]
															  attributes: inputAttributes];				
			}
			if ([activeItem result]) {
				responseString = [[NSAttributedString alloc] initWithString: [activeItem result]
																 attributes: transcriptAttributes];				
			}
			
			if (responseString) {
				[result insertAttributedString: responseString
									   atIndex: 0];				
			}
			if (inputString && [activeItem parent]) {
				[result insertAttributedString: newline
									   atIndex: 0];
				[result insertAttributedString: inputString
									   atIndex: 0];				
			}
			
			// Move up the tree
			activeItem = [activeItem parent];
		}
		
		// Add a title indicating which game this came from
		if (storyID) {
			// Write out the story ID
			[result insertAttributedString: newline
								   atIndex: 0];
			[result insertAttributedString: newline
								   atIndex: 0];
			[result insertAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"IFID: %@", [storyID description]]
																			 attributes: inputAttributes]
								   atIndex: 0];
			
			// Try to read the metadata for this story, if there is any
			ZoomMetadata* metadata = nil;
			ZoomStory* story = nil;
			NSData* userData = [NSData dataWithContentsOfFile: [zoomConfigDirectory() stringByAppendingPathComponent: @"metadata.iFiction"]];
			if (userData) metadata = [[ZoomMetadata alloc] initWithData: userData];
			
			if (metadata) {
				story = [metadata containsStoryWithIdent: storyID]?[metadata findOrCreateStory: storyID]:nil;
			}
			
			if (story && [[story title] length] > 0) {
				[result insertAttributedString: newline
									   atIndex: 0];
				[result insertAttributedString: [[NSAttributedString alloc] initWithString: [NSString stringWithFormat: @"Saved game from %@", [story title]]
																				 attributes: titleAttributes]
									   atIndex: 0];				
			}
		}
		
		// Set the quicklook data
		NSData *theRTF = [result RTFFromRange:NSMakeRange(0, [result length]-1) documentAttributes:@{}];
		QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)theRTF, kUTTypeRTF, NULL);
	}
	
    return noErr;
	}
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}

#pragma GCC visibility pop
