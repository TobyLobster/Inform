//
//  GlkBuffer.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkBuffer.h"

#define GlkBigBuffer 256

// = Strings for actions =

// Windows

// Creating the various types of window
static NSString* s_CreateBlankWindowWithIdentifier				= @"CBWI";
static NSString* s_CreateTextGridWindowWithIdentifier			= @"CTGW";
static NSString* s_CreateTextWindowWithIdentifier 				= @"CTWI";
static NSString* s_CreateGraphicsWindowWithIdentifier 			= @"CGWI";

// Placing windows in the tree
static NSString* s_SetRootWindow								= @"WSRW";
static NSString* s_CreatePairWindowWithIdentifier				= @"CPWI";

// Closing windows
static NSString* s_CloseWindowIdentifier 						= @"CLWI";

// Manipulating windows
static NSString* s_MoveCursorInWindow 							= @"MCIW";
static NSString* s_ClearWindowIdentifier 						= @"WINC";
static NSString* s_ClearWindowIdentifierWithBackground 			= @"WIBC";
static NSString* s_SetInputLine 								= @"WSIL";
static NSString* s_ArrangeWindow 								= @"WARR";

// Styles
static NSString* s_SetStyleHint 								= @"ISSH";
static NSString* s_ClearStyleHint 								= @"ICSH";

static NSString* s_SetStyleHintStream 							= @"SSSH";
static NSString* s_ClearStyleHintStream 						= @"SCSH";
static NSString* s_SetCustomAttributesStream 					= @"SSCA";

// Graphics
static NSString* s_FillAreaInWindowWithIdentifier 				= @"GFAW";
static NSString* s_DrawImageWithIdentifier 						= @"GDIP";
static NSString* s_DrawImageWithIdentifierInRect 				= @"GDIR";

static NSString* s_DrawImageWithIdentifierAlign 				= @"GDIA";
static NSString* s_DrawImageWithIdentifierAlignSize 			= @"GDIS";

static NSString* s_BreakFlowInWindowWithIdentifier 				= @"GBFW";

// Streams

// Registering streams
static NSString* s_RegisterStream 								= @"SRSS";
static NSString* s_RegisterStreamForWindow 						= @"SRSW";

static NSString* s_CloseStreamIdentifier 						= @"SCSI";
static NSString* s_UnregisterStreamIdentifier 					= @"SUSI";	// If the stream is closed immediately

// Buffering stream writes
static NSString* s_PutCharToStream 								= @"SPCH";
static NSString* s_PutStringToStream 							= @"SPST";
static NSString* s_PutDataToStream 								= @"SPDA";
static NSString* s_SetStyle 									= @"SSSS";

// Hyperlinks on streams
static NSString* s_SetHyperlink 								= @"SHYS";
static NSString* s_ClearHyperlinkOnStream 						= @"SCLH";

// Events

// Requesting events
static NSString* s_RequestLineEventsForWindowIdentifier 		= @"ERLE";
static NSString* s_RequestCharEventsForWindowIdentifier			= @"ERCE";
static NSString* s_RequestMouseEventsForWindowIdentifier		= @"ERME";
static NSString* s_RequestHyperlinkEventsForWindowIdentifier	= @"ERHE";

static NSString* s_CancelCharEventsForWindowIdentifier 			= @"ECCE";
static NSString* s_CancelMouseEventsForWindowIdentifier 		= @"ECME";
static NSString* s_CancelHyperlinkEventsForWindowIdentifier 	= @"ECHE";

@implementation GlkBuffer

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		operations = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[operations release];
	
	[super dealloc];
}

// = Buffering =

static NSString* stringFromOp(NSArray* op) {
	NSString* opType = [op objectAtIndex: 0];
	
	if ([opType isEqualToString: s_PutCharToStream]) {
		unichar ch = [[[op objectAtIndex: 1] objectAtIndex: 0] unsignedIntValue];
		
		if (ch < 32) return nil;
		
		return [NSString stringWithCharacters: &ch
									   length: 1];
	} else if ([opType isEqualToString: s_PutStringToStream]) {
		NSString* str = [[op objectAtIndex: 1] objectAtIndex: 0];
		
		return str;
	}
	
	return nil;
}

- (void) addOperation: (NSString*) name
			arguments: (NSArray*) arguments {
	NSArray* op = [NSArray arrayWithObjects: name, arguments, nil];
	
	if ([name isEqualToString: s_PutCharToStream]
		|| [name isEqualToString: s_PutStringToStream]
		|| [name isEqualToString: s_PutDataToStream]) {
#if 0
		// (Commented out, this currently screws up when concatenating, as we don't want to keep copying the data there)
		// We're probably OK, though, as it's bad practice to pass in data to one of these calls that can change
		// For data operations, ensure that the NSData object is not mutable (or is a copy)
		if ([op selector] == @selector(putData:toStream:)) {
			NSData* opData;
			[op getArgument: &opData
					atIndex: 2];
			
			if ([opData isKindOfClass: [NSMutableData class]]) {
				opData = [[opData copy] autorelease];
				[op setArgument: &opData
						atIndex: 2];
			}
		}
#endif
		
		int 		opPos 		= [operations count] - 1;
		NSArray* 	lastOp 		= [operations lastObject];
		int 		stream, lastStream;
		
		while (lastOp && ([[lastOp objectAtIndex: 0] isEqualToString: s_PutCharToStream] ||
						  [[lastOp objectAtIndex: 0] isEqualToString: s_PutStringToStream] ||
						  [[lastOp objectAtIndex: 0] isEqualToString: s_PutDataToStream])) {
			// Skip backwards past 'ignorable' selectors until we find a write to this stream
			stream 		= [[arguments objectAtIndex: 1] intValue];
			lastStream	= [[[lastOp objectAtIndex: 1] objectAtIndex: 1] intValue];
			
			if (stream == lastStream) break;	// We've found the 'interesting' operation
			
			// Go back to the previous operation
			if (opPos > 0) {
				opPos--;
				lastOp = [operations objectAtIndex: opPos];
			} else {
				lastOp = nil;
			}
		}
		
		if (lastOp &&
			([[lastOp objectAtIndex: 0] isEqualToString: s_PutCharToStream] ||
			 [[lastOp objectAtIndex: 0] isEqualToString: s_PutStringToStream]) &&
			![name isEqualToString: s_PutDataToStream] &&
			stream == lastStream) {
			// If both of these have the same stream identifier, then we might be able to merge them into one operation
			NSString* lastString, *string;
				
			lastString 	= stringFromOp(lastOp);
			string 		= stringFromOp(op);
				
			if (lastString && string) {
				[operations removeObjectAtIndex: opPos];
				[self putString: [lastString stringByAppendingString: string]
						toStream: stream];
				return;
			}
		} else if (lastOp &&
				   [[lastOp objectAtIndex: 0] isEqualToString: s_PutDataToStream] &&
				   [name isEqualToString: s_PutDataToStream] &&
				   stream == lastStream) {
			// Data writes can also be concatenated
			NSData* oldData 	= [[lastOp objectAtIndex: 1] objectAtIndex: 0];
			NSData* nextData 	= [arguments objectAtIndex: 0];
			
			NSMutableData* newData = nil;
			if ([oldData isKindOfClass: [NSMutableData class]]) {
				newData = (NSMutableData*)oldData;
			} else {
				newData = [[oldData mutableCopy] autorelease];
			}
			
			if (newData && nextData) {
				[newData appendData: nextData];
				[operations removeObjectAtIndex: opPos];
				[self putData: newData
					 toStream: stream];
				return;
			}
		}			
	}

	// Add to the list of operations
	[operations addObject: op];
}

- (BOOL) shouldBeFlushed {
	return [operations count]>0;
}

- (BOOL) hasGotABitOnTheLargeSide {
	return [operations count] > GlkBigBuffer;
}

// = NSCoding =

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	if (self) {
		operations = [[NSMutableArray alloc] initWithArray: [coder decodeObject]
												 copyItems: NO];
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeObject: operations];
}

- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
	// This ensures that when we're passed in a bycopy way, we get passed as an actual copy and not a NSDistantObject
	// (which would kind of defeat the whole purpose of the buffer in the first place)
	if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];	
}

// = NSCopying =

- (id) copyWithZone: (NSZone*) zone {
	GlkBuffer* copy = [[GlkBuffer alloc] init];
	
	[copy->operations release];
	copy->operations = [[NSMutableArray alloc] initWithArray: operations
												   copyItems: YES];
	
	return copy;
}

// = Method invocations =

// Windows

// Creating the various types of window
- (void) createBlankWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateBlankWindowWithIdentifier
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

- (void) createTextGridWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateTextGridWindowWithIdentifier
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

- (void) createTextWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateTextWindowWithIdentifier
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

- (void) createGraphicsWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateGraphicsWindowWithIdentifier
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

// Placing windows in the tree
- (void) setRootWindow: (glui32) identifier {
	[self addOperation: s_SetRootWindow
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

- (void) createPairWindowWithIdentifier: (glui32) identifier
							  keyWindow: (glui32) keyIdentifier
							 leftWindow: (glui32) leftIdentifier
							rightWindow: (glui32) rightIdentifier
								 method: (glui32) method
								   size: (glui32) size {
	[self addOperation: s_CreatePairWindowWithIdentifier
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: identifier]
			 		  							 , [NSNumber numberWithUnsignedInt: keyIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: leftIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: rightIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: method]
			 		  							 , [NSNumber numberWithUnsignedInt: size]
			 		  							 , nil]];
}

// Closing windows
- (void) closeWindowIdentifier: (glui32) identifier {
	[self addOperation: s_CloseWindowIdentifier
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

// Manipulating windows
- (void) moveCursorInWindow: (glui32) identifier
				toXposition: (int) xpos
				  yPosition: (int) ypos {
	[self addOperation: s_MoveCursorInWindow
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: identifier]
			 		  							 , [NSNumber numberWithUnsignedInt: xpos]
			 		  							 , [NSNumber numberWithUnsignedInt: ypos]
			 		  							 , nil]];
}

- (void) clearWindowIdentifier: (glui32) identifier {
	[self addOperation: s_ClearWindowIdentifier
			 arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: identifier]]];
}

- (void) clearWindowIdentifier: (glui32) identifier
		  withBackgroundColour: (in bycopy NSColor*) bgColour {
	[self addOperation: s_ClearWindowIdentifierWithBackground
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: identifier]
			 		  							 , bgColour
			 		  							 , nil]];
}

- (void) setInputLine: (in bycopy NSString*) inputLine
  forWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_SetInputLine
			 arguments: [NSArray arrayWithObjects: inputLine
			 		  							 , [NSNumber numberWithUnsignedInt: windowIdentifier]
			 		  							 , nil]];
}

- (void) arrangeWindow: (glui32) identifier
				method: (glui32) method
				  size: (glui32) size
			 keyWindow: (glui32) keyIdentifier {
	[self addOperation: s_ArrangeWindow
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: identifier]
			 		  							 , [NSNumber numberWithUnsignedInt: method]
			 		  							 , [NSNumber numberWithUnsignedInt: size]
			 		  							 , [NSNumber numberWithUnsignedInt: keyIdentifier]
			 		  							 , nil]];
}

// Styles
- (void) setStyleHint: (glui32) hint
			 forStyle: (glui32) style
			  toValue: (glsi32) value
		   windowType: (glui32) wintype {
	[self addOperation: s_SetStyleHint
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: hint]
			 		  							 , [NSNumber numberWithUnsignedInt: style]
			 		  							 , [NSNumber numberWithUnsignedInt: value]
			 		  							 , [NSNumber numberWithUnsignedInt: wintype]
			 		  							 , nil]];
}

- (void) clearStyleHint: (glui32) hint
			   forStyle: (glui32) style
			 windowType: (glui32) wintype {
	[self addOperation: s_ClearStyleHint
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: hint]
			 		  							 , [NSNumber numberWithUnsignedInt: style]
			 		  							 , [NSNumber numberWithUnsignedInt: wintype]
			 		  							 , nil]];
}

- (void) setStyleHint: (glui32) hint
			  toValue: (glsi32) value
			 inStream: (glui32) streamIdentifier {
	[self addOperation: s_SetStyleHintStream
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: hint]
			 		  							 , [NSNumber numberWithUnsignedInt: value]
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) clearStyleHint: (glui32) hint
			   inStream: (glui32) streamIdentifier {
	[self addOperation: s_ClearStyleHintStream
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: hint]
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) setCustomAttributes: (NSDictionary*) attributes
					inStream: (glui32) streamIdentifier {
	[self addOperation: s_SetCustomAttributesStream
			 arguments: [NSArray arrayWithObjects: attributes
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

// Graphics
- (void) fillAreaInWindowWithIdentifier: (unsigned) identifier
							 withColour: (in bycopy NSColor*) color
							  rectangle: (NSRect) windowArea {
	[self addOperation: s_FillAreaInWindowWithIdentifier
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: identifier]
			 		  							 , color
			 		  							 , [NSValue valueWithRect: windowArea]
			 		  							 , nil]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					  atPosition: (NSPoint) position {
	[self addOperation: s_DrawImageWithIdentifier
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: imageIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: windowIdentifier]
			 		  							 , [NSValue valueWithPoint: position]
			 		  							 , nil]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
						  inRect: (NSRect) imageRect {
	[self addOperation: s_DrawImageWithIdentifierInRect
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: imageIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: windowIdentifier]
			 		  							 , [NSValue valueWithRect: imageRect]
			 		  							 , nil]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment {
	[self addOperation: s_DrawImageWithIdentifierAlign
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: imageIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: windowIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: alignment]
			 		  							 , nil]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment
							size: (NSSize) imageSize {
	[self addOperation: s_DrawImageWithIdentifierAlignSize
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: imageIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: windowIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: alignment]
			 		  							 , [NSValue valueWithSize: imageSize]
			 		  							 , nil]];
}

- (void) breakFlowInWindowWithIdentifier: (unsigned) identifier {
	[self addOperation: s_BreakFlowInWindowWithIdentifier
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: identifier]
			 		  							 , nil]];
}

// Streams

// Registering streams
- (void) registerStream: (in byref NSObject<GlkStream>*) stream
		  forIdentifier: (unsigned) streamIdentifier  {
	[self addOperation: s_RegisterStream
			 arguments: [NSArray arrayWithObjects: stream
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) registerStreamForWindow: (unsigned) windowIdentifier
				   forIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_RegisterStreamForWindow
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: windowIdentifier]
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) closeStreamIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_CloseStreamIdentifier
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) unregisterStreamIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_UnregisterStreamIdentifier
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

// Buffering stream writes
- (void) putChar: (unichar) ch
		toStream: (unsigned) streamIdentifier {
	[self addOperation: s_PutCharToStream
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: ch]
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) putString: (in bycopy NSString*) string
		  toStream: (unsigned) streamIdentifier  {
	[self addOperation: s_PutStringToStream
			 arguments: [NSArray arrayWithObjects: string
												 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) putData: (in bycopy NSData*) data							// Note: do not pass in mutable data here, as the contents may change unexpectedly
		toStream: (unsigned) streamIdentifier {
	[self addOperation: s_PutDataToStream
			 arguments: [NSArray arrayWithObjects: data
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) setStyle: (unsigned) style
		 onStream: (unsigned) streamIdentifier {
	[self addOperation: s_SetStyle
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: style]
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}


// Hyperlinks on streams
- (void) setHyperlink: (unsigned int) value
			 onStream: (unsigned) streamIdentifier {
	[self addOperation: s_SetHyperlink
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: value]
			 		  							 , [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

- (void) clearHyperlinkOnStream: (unsigned) streamIdentifier {
	[self addOperation: s_ClearHyperlinkOnStream
			 arguments: [NSArray arrayWithObjects: [NSNumber numberWithUnsignedInt: streamIdentifier]
			 		  							 , nil]];
}

// Events

// Requesting events
- (void) requestLineEventsForWindowIdentifier:      (unsigned) windowIdentifier {
	[self addOperation: s_RequestLineEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

- (void) requestCharEventsForWindowIdentifier:      (unsigned) windowIdentifier {
	[self addOperation: s_RequestCharEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

- (void) requestMouseEventsForWindowIdentifier:     (unsigned) windowIdentifier {
	[self addOperation: s_RequestMouseEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

- (void) requestHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_RequestHyperlinkEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

- (void) cancelCharEventsForWindowIdentifier:      (unsigned) windowIdentifier {
	[self addOperation: s_CancelCharEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

- (void) cancelMouseEventsForWindowIdentifier:     (unsigned) windowIdentifier {
	[self addOperation: s_CancelMouseEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

- (void) cancelHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_CancelHyperlinkEventsForWindowIdentifier
		     arguments: [NSArray arrayWithObject: [NSNumber numberWithUnsignedInt: windowIdentifier]]];
}

/// = Buffer flushing =


- (void) flushToTarget: (id) target {
	// Iterate through the operations
	NSEnumerator* bufferEnum = [operations objectEnumerator];
	NSArray* op;
	
	// Decode each operation in turn using a giant if statements of death
	while (op = [bufferEnum nextObject]) {
		NSString*	opType 	= [op objectAtIndex: 0];
		NSArray* 	args 	= [op objectAtIndex: 1];
			
		// Buffering stream writes
		if ([opType isEqualToString: s_PutCharToStream]) {
			[target putChar: [[args objectAtIndex: 0] unsignedIntValue]
				 toStream: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_PutStringToStream]) {
			[target putString: [args objectAtIndex: 0]
				   toStream: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_PutDataToStream]) {
			[target putData: [args objectAtIndex: 0]
				 toStream: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_SetStyle]) {
			[target setStyle: [[args objectAtIndex: 0] unsignedIntValue]
			      onStream: [[args objectAtIndex: 1] unsignedIntValue]];

		// Graphics
		} else if ([opType isEqualToString: s_FillAreaInWindowWithIdentifier]) {
			[target fillAreaInWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   			          withColour: [args objectAtIndex: 1]
			                           rectangle: [[args objectAtIndex: 2] rectValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifier]) {
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
			       inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue]
			                   atPosition: [[args objectAtIndex: 2] pointValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierInRect]) {
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue]
								   inRect: [[args objectAtIndex: 2] rectValue]];
		
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierAlign]) {
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue] 
								alignment: [[args objectAtIndex: 2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierAlignSize]) {
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue] 
								alignment: [[args objectAtIndex: 2] unsignedIntValue]
									 size: [[args objectAtIndex: 3] sizeValue]];
		
		} else if ([opType isEqualToString: s_BreakFlowInWindowWithIdentifier]) {
			[target breakFlowInWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		
		// Manipulating windows
		} else if ([opType isEqualToString: s_MoveCursorInWindow]) {
			[target moveCursorInWindow: [[args objectAtIndex: 0] unsignedIntValue]
						 toXposition: [[args objectAtIndex: 1] unsignedIntValue] 
						   yPosition: [[args objectAtIndex: 2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearWindowIdentifier]) {
			[target clearWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearWindowIdentifierWithBackground]) {
			[target clearWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   withBackgroundColour: [args objectAtIndex: 1]];
		} else if ([opType isEqualToString: s_SetInputLine]) {
			[target setInputLine: [args objectAtIndex: 0]
		   forWindowIdentifier: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ArrangeWindow]) {
			[target arrangeWindow: [[args objectAtIndex: 0] unsignedIntValue]
						 method: [[args objectAtIndex: 1] unsignedIntValue]
						   size: [[args objectAtIndex: 2] unsignedIntValue]
					  keyWindow: [[args objectAtIndex: 3] unsignedIntValue]];
		
		// Styles
		} else if ([opType isEqualToString: s_SetStyleHint]) {
			[target setStyleHint: [[args objectAtIndex: 0] unsignedIntValue]
					  forStyle: [[args objectAtIndex: 1] unsignedIntValue]
					   toValue: [[args objectAtIndex: 2] unsignedIntValue] 
					windowType: [[args objectAtIndex: 3] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearStyleHint]) {
			[target clearStyleHint: [[args objectAtIndex: 0] unsignedIntValue] 
						forStyle: [[args objectAtIndex: 1] unsignedIntValue] 
					  windowType: [[args objectAtIndex: 2] unsignedIntValue]];
		
		} else if ([opType isEqualToString: s_SetStyleHintStream]) {
			[target setStyleHint: [[args objectAtIndex: 0] unsignedIntValue] 
					   toValue: [[args objectAtIndex: 1] unsignedIntValue] 
					  inStream: [[args objectAtIndex: 2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearStyleHintStream]) {
			[target clearStyleHint: [[args objectAtIndex: 0] unsignedIntValue] 
						inStream: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_SetCustomAttributesStream]) {
			[target setCustomAttributes: [args objectAtIndex: 0] 
							 inStream: [[args objectAtIndex: 1] unsignedIntValue]];
		
		// Hyperlinks on streams
		} else if ([opType isEqualToString: s_SetHyperlink]) {
			[target setHyperlink: [[args objectAtIndex: 0] unsignedIntValue]
					  onStream: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearHyperlinkOnStream]) {
			[target clearHyperlinkOnStream: [[args objectAtIndex: 0] unsignedIntValue]];
		
		// Registering streams
		} else if ([opType isEqualToString: s_RegisterStream]) {
			[target registerStream: [args objectAtIndex: 0] 
				   forIdentifier: [[args objectAtIndex: 1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RegisterStreamForWindow]) {
			[target registerStreamForWindow: [[args objectAtIndex: 0] unsignedIntValue]
							forIdentifier: [[args objectAtIndex: 1] unsignedIntValue]];
		
		} else if ([opType isEqualToString: s_CloseStreamIdentifier]) {
			[target closeStreamIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_UnregisterStreamIdentifier]) {
			[target unregisterStreamIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		
		// Creating the various types of window
		} else if ([opType isEqualToString: s_CreateBlankWindowWithIdentifier]) {
			[target createBlankWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreateTextGridWindowWithIdentifier]) {
			[target createTextGridWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreateTextWindowWithIdentifier]) {
			[target createTextWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreateGraphicsWindowWithIdentifier]) {
			[target createGraphicsWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		
		// Placing windows in the tree
		} else if ([opType isEqualToString: s_SetRootWindow]) {
			[target setRootWindow: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreatePairWindowWithIdentifier]) {
			[target createPairWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue] 
									   keyWindow: [[args objectAtIndex: 1] unsignedIntValue] 
									  leftWindow: [[args objectAtIndex: 2] unsignedIntValue] 
									 rightWindow: [[args objectAtIndex: 3] unsignedIntValue] 
										  method: [[args objectAtIndex: 4] unsignedIntValue] 
											size: [[args objectAtIndex: 5] unsignedIntValue]];
		
		// Closing windows
		} else if ([opType isEqualToString: s_CloseWindowIdentifier]) {
			[target closeWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		
		// Events
		
		// Requesting events
		} else if ([opType isEqualToString: s_RequestLineEventsForWindowIdentifier]) {
			[target requestLineEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RequestCharEventsForWindowIdentifier]) {
			[target requestCharEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RequestMouseEventsForWindowIdentifier]) {
			[target requestMouseEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RequestHyperlinkEventsForWindowIdentifier]) {
			[target requestHyperlinkEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		
		} else if ([opType isEqualToString: s_CancelCharEventsForWindowIdentifier]) {
			[target cancelCharEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CancelMouseEventsForWindowIdentifier]) {
			[target cancelMouseEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CancelHyperlinkEventsForWindowIdentifier]) {
			[target cancelHyperlinkEventsForWindowIdentifier: [[args objectAtIndex: 0] unsignedIntValue]];
		} else {
			
			NSLog(@"Unknown action type: %@", opType);
		}
	}
}

@end
