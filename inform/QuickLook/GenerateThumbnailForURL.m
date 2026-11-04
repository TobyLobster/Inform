#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>

#import "IFSyntaxManager.h"

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef cfUrl, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	// Try to get the file that we're looking at
	NSString* fileName = nil;
	if (((__bridge NSURL*)cfUrl).fileURL) {
		fileName = ((__bridge NSURL*)cfUrl).path;
	}
	
	if (!fileName) {
		NSLog(@"No filename");
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
	int length = (int) sourceCodeString.length;
	if (length > 4096) length = 4096;
	NSTextStorage* storage = [[NSTextStorage alloc] initWithString: [sourceCodeString substringToIndex: length]];
    [IFSyntaxManager registerTextStorage: storage
                                    name: @"Thumbnail"
                                    type: isInform6 ? IFHighlightTypeInform6 : IFHighlightTypeInform7
                            intelligence: nil
                             undoManager: nil];

	// Produce the result
	CGSize size;
	size.width = 800;
	size.height = 840;
	CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, size, true, NULL);
	
    NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithCGContext: cgContext
                                                                         flipped: NO];
	
	// Start drawing
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext: context];
	context.imageInterpolation = NSImageInterpolationHigh;
	
	// Draw the background
	[NSGraphicsContext saveGraphicsState];
	NSShadow* shadow = [[NSShadow alloc] init];
	shadow.shadowOffset = NSMakeSize(0, -7);
	shadow.shadowBlurRadius = 7;
	[shadow set];
	NSGradient* gradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithDeviceRed: 0.95
																							green: 0.95
																							 blue: 0.95
																							alpha: 1.0]
														 endingColor: [NSColor whiteColor]];
	[gradient drawInRect: NSMakeRect(8,16, size.width-16, size.height - 24)
				   angle: 250];
	[NSGraphicsContext restoreGraphicsState];
	
	// Draw the source text
	[storage drawInRect: NSMakeRect(16, 24, size.width-32, size.height - 40)];
	
	// Draw 'Inform'
	NSMutableParagraphStyle* centered = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	centered.alignment = NSTextAlignmentCenter;
#ifndef __clang_analyzer__
    [@"Inform" drawInRect: NSMakeRect(16, 32, size.width-32, 70)
		   withAttributes: @{NSFontAttributeName: [NSFont boldSystemFontOfSize: 64],
							NSForegroundColorAttributeName: [NSColor colorWithDeviceRed: 0
												  green: 0
												   blue: 0
												  alpha: 0.6],
							NSParagraphStyleAttributeName: centered}];
#endif
	// Done with the drawing
	[NSGraphicsContext restoreGraphicsState];
	
	// Finish up with the context
	QLThumbnailRequestFlushContext(thumbnail, cgContext);
	CFRelease(cgContext);
	
    [IFSyntaxManager unregisterTextStorage: storage];
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
