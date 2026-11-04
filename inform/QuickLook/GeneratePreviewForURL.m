#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "IFSyntaxManager.h"

/* -----------------------------------------------------------------------------
   Generate a preview for file

   This function's job is to create preview for designated file
   ----------------------------------------------------------------------------- */

OSStatus GeneratePreviewForURL(void *thisInterface, 
							   QLPreviewRequestRef preview,
							   CFURLRef cfUrl, 
							   CFStringRef contentTypeUTI, 
							   CFDictionaryRef options)
{	
	// Try to get the file that we're looking at
	NSString* fileName = nil;
	if (((__bridge NSURL*)cfUrl).fileURL) {
		fileName = ((__bridge NSURL*)cfUrl).path;
	}
	
	if (!fileName) {
		return noErr;
	}
	
	// Try to get the source code
	BOOL isInform6 = NO;
	NSString* sourceCodeString = nil;
	
	NSString* uti = (__bridge NSString*) contentTypeUTI;

	if ([uti isEqualToString: @"org.inform-fiction.source.inform7"]
		|| [uti isEqualToString: @"org.inform-fiction.inform7.extension"]) {
		// ni file
		
		sourceCodeString = [NSString stringWithContentsOfFile: fileName
													 encoding: NSUTF8StringEncoding
														error: nil];

	} else if ([uti isEqualToString: @"org.inform-fiction.source.inform6"]) {
		// inf file
		
		isInform6 = YES;
		sourceCodeString = [NSString stringWithContentsOfFile: fileName
													 encoding: NSISOLatin1StringEncoding
														error: nil];
		
	} else if ([uti isEqualToString: @"org.inform-fiction.project"]) {
		// project file
		
		isInform6 = NO;
		sourceCodeString = [NSString stringWithContentsOfFile: [[fileName stringByAppendingPathComponent: @"Source"] stringByAppendingPathComponent: @"story.ni"]
													 encoding: NSUTF8StringEncoding
														error: nil];
		
		if (sourceCodeString == nil) {
			sourceCodeString = [NSString stringWithContentsOfFile: [[fileName stringByAppendingPathComponent: @"Source"] stringByAppendingPathComponent: @"main.inf"]
														 encoding: NSISOLatin1StringEncoding
															error: nil];
			isInform6 = YES;
		}
		
    } else if ([uti isEqualToString: @"org.inform-fiction.xproject"]) {
        // extension project file

        isInform6 = NO;
        sourceCodeString = [NSString stringWithContentsOfFile: [[fileName stringByAppendingPathComponent: @"Source"] stringByAppendingPathComponent: @"extension.i7x"]
                                                     encoding: NSUTF8StringEncoding
                                                        error: nil];
    } else {
		NSLog(@"Unknown UTI: %@", uti);
		return noErr;
	}
	
	if (!sourceCodeString) {
		NSLog(@"No source code");
		return noErr;
	}

	// Create a suitable storage object and highlighter
	NSTextStorage* storage = [[NSTextStorage alloc] initWithString: sourceCodeString];
    [IFSyntaxManager registerTextStorage: storage
                                    name: @"preview"
                                    type: isInform6 ? IFHighlightTypeInform6 : IFHighlightTypeInform7
                            intelligence: nil
                             undoManager: nil];

	// Produce the result
    NSData *theRTF = nil;
    if(storage.length > 0 ) {
        theRTF = [storage RTFFromRange: NSMakeRange(0, storage.length)
                    documentAttributes: @{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}];
    }
	QLPreviewRequestSetDataRepresentation(preview, (__bridge CFDataRef)theRTF, kUTTypeRTF, NULL);
	
    [IFSyntaxManager unregisterTextStorage:storage];

    return noErr;
}

void CancelPreviewGeneration(void* thisInterface, QLPreviewRequestRef preview)
{
    // implement only if supported
}
