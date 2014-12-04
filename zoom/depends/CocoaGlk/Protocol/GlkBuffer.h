//
//  GlkBuffer.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#if defined(COCOAGLK_IPHONE)
# include <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import "GlkStreamProtocol.h"

#include "glk.h"

#define GlkNoWindow 0xffffffff

//
// The buffer is used to store operations before sending them across the communications link with the host task.
// This is required as sending messages using the DistributedObject mechanism is somewhat slow.
//
// Note that in Zoom and previous versions of CocoaGlk, the buffering was done by storing dictionaries detailing the
// operations to be performed. In this version, we presently send invocations. This might change later if this forces
// too much client/server communications (to selectors and an array of arguments)
//

//
// Buffer operations. These all must return void.
//
@protocol GlkBuffer

// Windows

// Creating the various types of window
- (void) createBlankWindowWithIdentifier: (glui32) identifier;
- (void) createTextGridWindowWithIdentifier: (glui32) identifier;
- (void) createTextWindowWithIdentifier: (glui32) identifer;
- (void) createGraphicsWindowWithIdentifier: (glui32) identifier;

// Placing windows in the tree
- (void) setRootWindow: (glui32) identifier;
- (void) createPairWindowWithIdentifier: (glui32) identifier
							  keyWindow: (glui32) keyIdentifier
							 leftWindow: (glui32) leftIdentifier
							rightWindow: (glui32) rightIdentifier
								 method: (glui32) method
								   size: (glui32) size;

// Closing windows
- (void) closeWindowIdentifier: (glui32) identifier;

// Manipulating windows
- (void) moveCursorInWindow: (glui32) identifier
				toXposition: (int) xpos
				  yPosition: (int) ypos;
- (void) clearWindowIdentifier: (glui32) identifier;
- (void) clearWindowIdentifier: (glui32) identifier
		  withBackgroundColour: (in bycopy NSColor*) bgColour;
- (void) setInputLine: (in bycopy NSString*) inputLine
  forWindowIdentifier: (unsigned) windowIdentifier;
- (void) arrangeWindow: (glui32) identifier
				method: (glui32) method
				  size: (glui32) size
			 keyWindow: (glui32) keyIdentifier;

// Styles
- (void) setStyleHint: (glui32) hint
			 forStyle: (glui32) style
			  toValue: (glsi32) value
		   windowType: (glui32) wintype;
- (void) clearStyleHint: (glui32) hint
			   forStyle: (glui32) style
			 windowType: (glui32) wintype;

- (void) setStyleHint: (glui32) hint
			  toValue: (glsi32) value
			 inStream: (glui32) streamIdentifier;
- (void) clearStyleHint: (glui32) hint
			   inStream: (glui32) streamIdentifier;
- (void) setCustomAttributes: (NSDictionary*) attributes
					inStream: (glui32) streamIdentifier;

// Graphics
#if !defined(COCOAGLK_IPHONE)
- (void) fillAreaInWindowWithIdentifier: (unsigned) identifier
							 withColour: (in bycopy NSColor*) color
							  rectangle: (NSRect) windowArea;
#else
- (void) fillAreaInWindowWithIdentifier: (unsigned) identifier
							 withColour: (in bycopy UIColor*) color
							  rectangle: (NSRect) windowArea;
#endif
- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					  atPosition: (NSPoint) position;
- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
						  inRect: (NSRect) imageRect;

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment;
- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment
							size: (NSSize) imageSize;

- (void) breakFlowInWindowWithIdentifier: (unsigned) identifier;

// Streams

// Registering streams
- (void) registerStream: (in byref NSObject<GlkStream>*) stream
		  forIdentifier: (unsigned) streamIdentifier;
- (void) registerStreamForWindow: (unsigned) windowIdentifier
				   forIdentifier: (unsigned) streamIdentifier;

- (void) closeStreamIdentifier: (unsigned) streamIdentifier;
- (void) unregisterStreamIdentifier: (unsigned) streamIdentifier;	// If the stream is closed immediately

// Buffering stream writes
- (void) putChar: (unichar) ch
		toStream: (unsigned) streamIdentifier;
- (void) putString: (in bycopy NSString*) string
		  toStream: (unsigned) streamIdentifier;
- (void) putData: (in bycopy NSData*) data							// Note: do not pass in mutable data here, as the contents may change unexpectedly
		toStream: (unsigned) streamIdentifier;
- (void) setStyle: (unsigned) style
		 onStream: (unsigned) streamIdentifier;

// Hyperlinks on streams
- (void) setHyperlink: (unsigned int) value
			 onStream: (unsigned) streamIdentifier;
- (void) clearHyperlinkOnStream: (unsigned) streamIdentifier;

// Events

// Requesting events
- (void) requestLineEventsForWindowIdentifier:      (unsigned) windowIdentifier;
- (void) requestCharEventsForWindowIdentifier:      (unsigned) windowIdentifier;
- (void) requestMouseEventsForWindowIdentifier:     (unsigned) windowIdentifier;
- (void) requestHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier;

- (void) cancelCharEventsForWindowIdentifier:      (unsigned) windowIdentifier;
- (void) cancelMouseEventsForWindowIdentifier:     (unsigned) windowIdentifier;
- (void) cancelHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier;

@end

//
// Class used to temporarily store bufferable operations before sending them to the server
//
@interface GlkBuffer : NSObject<NSCopying, NSCoding, GlkBuffer> {
	NSMutableArray* operations;
}

// Adding a generic bufferred operation
- (void) addOperation: (NSString*) name
			arguments: (NSArray*) arguments;

// Returns true if the buffer has anything to flush
- (BOOL) shouldBeFlushed;
- (BOOL) hasGotABitOnTheLargeSide;

// Flushing a buffer with a target
- (void) flushToTarget: (id) target;

@end
