//
//  GlkImageSourceProtocol.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 20/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

//
// When we have image resources, we need to be able to ask the client what they are. The client can provide
// an object of this type to provide image data in any of the formats that Cocoa's NSImage class can
// understand.
//
// By default, we use the gi_blorb_* functions to get image resources. glk doesn't have a means for getting
// images from other sources by default.
//

@protocol GlkImageSource

- (bycopy NSData*) dataForImageResource: (glui32) image;	// Retrieve the image data for a specified resource

@end
