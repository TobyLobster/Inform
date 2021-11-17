//
//  ZoomLowerWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomLowerWindow.h"


@implementation ZoomLowerWindow

- (id) initWithZoomView: (ZoomView*) zV {
    self = [super init];

    if (self) {
        zoomView = zV; // In Soviet Russia, zoomView retains us. 
		backgroundStyle = [[ZStyle alloc] init];
    }

    return self;
}

// Clears the window
- (oneway void) clearWithStyle: (in bycopy ZStyle*) style {
    // Clear the lower part of all the upper windows
    NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
    for (ZoomUpperWindow* win in upperEnum) {
        [win cutLines];
    }
    
	[zoomView clearLowerWindowWithStyle: style];
	//[zoomView rearrangeUpperWindows];
	[zoomView retileUpperWindowIfRequired];
    [zoomView scrollToEnd];
    [zoomView resetMorePrompt];
	[zoomView padToLowerWindow];
	
	backgroundStyle = [style copy];
}

@synthesize backgroundStyle;

// Sets the input focus to this window
- (oneway void) setFocus {
	[zoomView setFocusedView: self];
}

// Sending data to a window
- (oneway void) writeString: (in bycopy NSString*) string
           withStyle: (in bycopy ZStyle*) style {
	[zoomView writeAttributedString: [zoomView formatZString: string
												   withStyle: style]];
    //[[[zoomView textView] textStorage] appendAttributedString:
    //    [zoomView formatZString: string
    //                  withStyle: style]];
    //[[zoomView buffer] appendAttributedString:
    //    [zoomView formatZString: string
    //                  withStyle: style]];
    
	[zoomView orOutputText: string];
    [zoomView scrollToEnd];
    [zoomView displayMoreIfNecessary];
}

#pragma mark - NSCoding
#define BACKGROUNDSTYLECODINGKEY @"backgroundStyle"

- (void) encodeWithCoder: (NSCoder*) encoder {
	if (encoder.allowsKeyedCoding) {
		[encoder encodeObject: backgroundStyle forKey: BACKGROUNDSTYLECODINGKEY];
	} else {
		[encoder encodeObject: backgroundStyle];
	}
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
    if (self) {
		if (decoder.allowsKeyedCoding) {
			backgroundStyle = [decoder decodeObjectOfClass: [ZStyle class] forKey: BACKGROUNDSTYLECODINGKEY];
		} else {
			backgroundStyle = [decoder decodeObject];
		}
    }
	
    return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

@synthesize zoomView;

#pragma mark - Input styles

@synthesize inputStyle;

@end
