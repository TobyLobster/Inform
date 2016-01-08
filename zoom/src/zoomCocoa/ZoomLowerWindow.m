//
//  ZoomLowerWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Oct 08 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomLowerWindow.h"


@implementation ZoomLowerWindow

- (instancetype) initWithZoomView: (ZoomView*) zV {
    self = [super init];

    if (self) {
        zoomView = zV; // In Soviet Russia, zoomView retains us. 
		backgroundStyle = [[ZStyle alloc] init];
    }

    return self;
}

- (void) dealloc {
    // [zoomView release];
	[backgroundStyle release];
	[inputStyle release];
    [super dealloc];
}

// Clears the window
- (oneway void) clearWithStyle: (in bycopy ZStyle*) style {
    // Clear the lower part of all the upper windows
    NSEnumerator* upperEnum = [[zoomView upperWindows] objectEnumerator];
    ZoomUpperWindow* win;
    while (win = [upperEnum nextObject]) {
        [win cutLines];
    }
    
	[zoomView clearLowerWindowWithStyle: style];
	//[zoomView rearrangeUpperWindows];
	[zoomView retileUpperWindowIfRequired];
    [zoomView scrollToEnd];
    [zoomView resetMorePrompt];
	[zoomView padToLowerWindow];
	
	[backgroundStyle release];
	backgroundStyle = [style copy];
}

- (ZStyle*) backgroundStyle {
	return backgroundStyle;
}

// Sets the input focus to this window
- (oneway void) setFocus {
	[zoomView setFocusedView: self];
}

// Sending data to a window
- (oneway void) writeString: (in bycopy NSString*) string
                  withStyle: (in bycopy ZStyle*) style
                  isCommand: (in bycopy BOOL) isCommand {
	[zoomView writeAttributedString: [zoomView formatZString: string
												   withStyle: style]];
    //[[[zoomView textView] textStorage] appendAttributedString:
    //    [zoomView formatZString: string
    //                  withStyle: style]];
    //[[zoomView buffer] appendAttributedString:
    //    [zoomView formatZString: string
    //                  withStyle: style]];

    if( !isCommand ) {
        [zoomView orOutputText: string];
    }
    [zoomView scrollToEnd];
    [zoomView displayMoreIfNecessary];
}

// = NSCoding =
- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeObject: backgroundStyle];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [self initWithZoomView:nil];
	
    if (self) {
		backgroundStyle = [[decoder decodeObject] retain];
    }
	
    return self;
}

- (void) setZoomView: (ZoomView*) view {
	zoomView = view;
}

// = Input styles =

- (oneway void) setInputStyle: (in bycopy ZStyle*) newInputStyle {
	if (inputStyle) [inputStyle release];
	inputStyle = [newInputStyle copy];
}

- (bycopy ZStyle*) inputStyle {
	return inputStyle;
}

@end
