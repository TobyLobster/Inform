#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "ZoomBabel.h"

#pragma GCC visibility push(hidden)

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef cfUrl, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	@autoreleasepool {
	NSString* uti = (__bridge NSString*) contentTypeUTI;
	NSURL* url = (__bridge NSURL*) cfUrl;
	
	if ([uti isEqualToString: @"uk.org.logicalshift.glksave"]
		|| [uti isEqualToString: @"uk.org.logicalshift.zoomsave"]) {
	
		// Save games are not supported
		return noErr;
		
	} else {
		
		// Try to get the image via babel for this file
		if (![url isFileURL]) return noErr;
		
		ZoomBabel* babel = [[ZoomBabel alloc] initWithFilename: [url path]];
		NSData* imageData = [babel rawCoverImage];
		
		if (imageData) {
			// Use the image as the thumbnail
			QLThumbnailRequestSetImageWithData(thumbnail, (__bridge CFDataRef)imageData, NULL);
		}
		
	}
	
    return noErr;
	}
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}

#pragma GCC visibility pop
