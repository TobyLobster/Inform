//
//  GlkBuffer.h
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#ifndef __GLKVIEW_GLKBUFFER_H__
#define __GLKVIEW_GLKBUFFER_H__

#import <GlkView/GlkViewDefinitions.h>
#if defined(COCOAGLK_IPHONE)
# import <UIKit/UIKit.h>
#else
# import <Cocoa/Cocoa.h>
#endif

#import <GlkView/GlkStreamProtocol.h>

#include <GlkView/glk.h>

#define GlkNoWindow 0xffffffff

///
/// Buffer operations. These all must return void.
///
/// The buffer is used to store operations before sending them across the communications link with the host task.
/// This is required as sending messages using the DistributedObject mechanism is somewhat slow.
///
/// Note that in Zoom and previous versions of CocoaGlk, the buffering was done by storing dictionaries detailing the
/// operations to be performed. In this version, we presently send invocations. This might change later if this forces
/// too much client/server communications (to selectors and an array of arguments)
///
@protocol GlkBuffer <NSObject>

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
		  withBackgroundColour: (in bycopy GlkColor*) bgColour;
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
- (void) fillAreaInWindowWithIdentifier: (unsigned) identifier
							 withColour: (in bycopy GlkColor*) color
							  rectangle: (GlkRect) windowArea;
- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					  atPosition: (GlkPoint) position;
- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
						  inRect: (GlkRect) imageRect;

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment;
- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment
							size: (GlkCocoaSize) imageSize;

- (void) breakFlowInWindowWithIdentifier: (unsigned) identifier;

// Streams

// Registering streams
- (void) registerStream: (in byref id<GlkStream>) stream
		  forIdentifier: (unsigned) streamIdentifier;
- (void) registerStreamForWindow: (unsigned) windowIdentifier
				   forIdentifier: (unsigned) streamIdentifier;

- (void) closeStreamIdentifier: (unsigned) streamIdentifier;
/// If the stream is closed immediately
- (void) unregisterStreamIdentifier: (unsigned) streamIdentifier;

// Buffering stream writes
- (void) putChar: (unichar) ch
		toStream: (unsigned) streamIdentifier;
- (void) putString: (in bycopy NSString*) string
		  toStream: (unsigned) streamIdentifier;
/// Note: do not pass in mutable data here, as the contents may change unexpectedly
- (void) putData: (in bycopy NSData*) data
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

///
/// Class used to temporarily store bufferable operations before sending them to the server
///
@interface GlkBuffer : NSObject<NSCopying, NSSecureCoding, GlkBuffer> {
	NSMutableArray* operations;
}

/// Adding a generic bufferred operation
- (void) addOperation: (NSString*) name
			arguments: (NSArray*) arguments;

/// Returns true if the buffer has anything to flush
@property (readonly) BOOL shouldBeFlushed;
@property (readonly) BOOL hasGotABitOnTheLargeSide;

/// Flushing a buffer with a target
- (void) flushToTarget: (id<GlkBuffer>) target;

@end

#endif
