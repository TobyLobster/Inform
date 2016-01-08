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

@implementation GlkBuffer {
    NSMutableArray* operations;
}

// = Initialisation =

- (instancetype) init {
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
	NSString* opType = op[0];
	
	if ([opType isEqualToString: s_PutCharToStream]) {
		unichar ch = [op[1][0] unsignedIntValue];
		
		if (ch < 32) return nil;
		
		return [NSString stringWithCharacters: &ch
									   length: 1];
	} else if ([opType isEqualToString: s_PutStringToStream]) {
		NSString* str = op[1][0];
		
		return str;
	}
	
	return nil;
}

- (void) addOperation: (NSString*) name
			arguments: (NSArray*) arguments {
	NSArray* op = @[name, arguments];
	
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
		
		int 		opPos 		= (int)[operations count] - 1;
		NSArray* 	lastOp 		= [operations lastObject];
		int 		stream, lastStream;
		
		while (lastOp && ([lastOp[0] isEqualToString: s_PutCharToStream] ||
						  [lastOp[0] isEqualToString: s_PutStringToStream] ||
						  [lastOp[0] isEqualToString: s_PutDataToStream])) {
			// Skip backwards past 'ignorable' selectors until we find a write to this stream
			stream 		= [arguments[1] intValue];
			lastStream	= [lastOp[1][1] intValue];
			
			if (stream == lastStream) break;	// We've found the 'interesting' operation
			
			// Go back to the previous operation
			if (opPos > 0) {
				opPos--;
				lastOp = operations[opPos];
			} else {
				lastOp = nil;
			}
		}
		
		if (lastOp &&
			([lastOp[0] isEqualToString: s_PutCharToStream] ||
			 [lastOp[0] isEqualToString: s_PutStringToStream]) &&
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
				   [lastOp[0] isEqualToString: s_PutDataToStream] &&
				   [name isEqualToString: s_PutDataToStream] &&
				   stream == lastStream) {
			// Data writes can also be concatenated
			NSData* oldData 	= lastOp[1][0];
			NSData* nextData 	= arguments[0];
			
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

- (instancetype) initWithCoder: (NSCoder*) coder {
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
			 arguments: @[@(identifier)]];
}

- (void) createTextGridWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateTextGridWindowWithIdentifier
			 arguments: @[@(identifier)]];
}

- (void) createTextWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateTextWindowWithIdentifier
			 arguments: @[@(identifier)]];
}

- (void) createGraphicsWindowWithIdentifier: (glui32) identifier {
	[self addOperation: s_CreateGraphicsWindowWithIdentifier
			 arguments: @[@(identifier)]];
}

// Placing windows in the tree
- (void) setRootWindow: (glui32) identifier {
	[self addOperation: s_SetRootWindow
			 arguments: @[@(identifier)]];
}

- (void) createPairWindowWithIdentifier: (glui32) identifier
							  keyWindow: (glui32) keyIdentifier
							 leftWindow: (glui32) leftIdentifier
							rightWindow: (glui32) rightIdentifier
								 method: (glui32) method
								   size: (glui32) size {
	[self addOperation: s_CreatePairWindowWithIdentifier
			 arguments: @[@(identifier)
                        , @(keyIdentifier)
                        , @(leftIdentifier)
                        , @(rightIdentifier)
                        , @(method)
                        , @(size)]];
}

// Closing windows
- (void) closeWindowIdentifier: (glui32) identifier {
	[self addOperation: s_CloseWindowIdentifier
			 arguments: @[@(identifier)]];
}

// Manipulating windows
- (void) moveCursorInWindow: (glui32) identifier
				toXposition: (int) xpos
				  yPosition: (int) ypos {
	[self addOperation: s_MoveCursorInWindow
			 arguments: @[@(identifier)
                         , [NSNumber numberWithUnsignedInt: xpos]
                         , [NSNumber numberWithUnsignedInt: ypos]]];
}

- (void) clearWindowIdentifier: (glui32) identifier {
	[self addOperation: s_ClearWindowIdentifier
			 arguments: @[@(identifier)]];
}

- (void) clearWindowIdentifier: (glui32) identifier
		  withBackgroundColour: (in bycopy NSColor*) bgColour {
	[self addOperation: s_ClearWindowIdentifierWithBackground
			 arguments: @[@(identifier)
			 		  	 , bgColour]];
}

- (void) setInputLine: (in bycopy NSString*) inputLine
  forWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_SetInputLine
			 arguments: @[inputLine
			 		  	 , @(windowIdentifier)]];
}

- (void) arrangeWindow: (glui32) identifier
				method: (glui32) method
				  size: (glui32) size
			 keyWindow: (glui32) keyIdentifier {
	[self addOperation: s_ArrangeWindow
			 arguments: @[@(identifier)
                        , @(method)
                        , @(size)
                        , @(keyIdentifier)]];
}

// Styles
- (void) setStyleHint: (glui32) hint
			 forStyle: (glui32) style
			  toValue: (glsi32) value
		   windowType: (glui32) wintype {
	[self addOperation: s_SetStyleHint
			 arguments: @[@(hint)
                        , @(style)
                        , [NSNumber numberWithUnsignedInt: value]
                        , @(wintype)]];
}

- (void) clearStyleHint: (glui32) hint
			   forStyle: (glui32) style
			 windowType: (glui32) wintype {
	[self addOperation: s_ClearStyleHint
			 arguments: @[@(hint)
                        , @(style)
                        , @(wintype)]];
}

- (void) setStyleHint: (glui32) hint
			  toValue: (glsi32) value
			 inStream: (glui32) streamIdentifier {
	[self addOperation: s_SetStyleHintStream
			 arguments: @[@(hint)
                        , [NSNumber numberWithUnsignedInt: value]
                        , @(streamIdentifier)]];
}

- (void) clearStyleHint: (glui32) hint
			   inStream: (glui32) streamIdentifier {
	[self addOperation: s_ClearStyleHintStream
			 arguments: @[@(hint)
			 		  							 , @(streamIdentifier)]];
}

- (void) setCustomAttributes: (NSDictionary*) attributes
					inStream: (glui32) streamIdentifier {
	[self addOperation: s_SetCustomAttributesStream
			 arguments: @[attributes
                        , @(streamIdentifier)]];
}

// Graphics
- (void) fillAreaInWindowWithIdentifier: (unsigned) identifier
							 withColour: (in bycopy NSColor*) color
							  rectangle: (NSRect) windowArea {
	[self addOperation: s_FillAreaInWindowWithIdentifier
			 arguments: @[@(identifier)
                         , color
                         , [NSValue valueWithRect: windowArea]]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					  atPosition: (NSPoint) position {
	[self addOperation: s_DrawImageWithIdentifier
			 arguments: @[@(imageIdentifier)
                        , @(windowIdentifier)
                        , [NSValue valueWithPoint: position]]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
						  inRect: (NSRect) imageRect {
	[self addOperation: s_DrawImageWithIdentifierInRect
			 arguments: @[@(imageIdentifier)
                        , @(windowIdentifier)
                        , [NSValue valueWithRect: imageRect]]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment {
	[self addOperation: s_DrawImageWithIdentifierAlign
			 arguments: @[@(imageIdentifier)
                        , @(windowIdentifier)
                        , @(alignment)]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment
							size: (NSSize) imageSize {
	[self addOperation: s_DrawImageWithIdentifierAlignSize
			 arguments: @[@(imageIdentifier)
                        , @(windowIdentifier)
                        , @(alignment)
                        , [NSValue valueWithSize: imageSize]]];
}

- (void) breakFlowInWindowWithIdentifier: (unsigned) identifier {
	[self addOperation: s_BreakFlowInWindowWithIdentifier
			 arguments: @[@(identifier)]];
}

// Streams

// Registering streams
- (void) registerStream: (in byref NSObject<GlkStream>*) stream
		  forIdentifier: (unsigned) streamIdentifier  {
	[self addOperation: s_RegisterStream
			 arguments: @[stream
                        , @(streamIdentifier)]];
}

- (void) registerStreamForWindow: (unsigned) windowIdentifier
				   forIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_RegisterStreamForWindow
			 arguments: @[@(windowIdentifier)
                        , @(streamIdentifier)]];
}

- (void) closeStreamIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_CloseStreamIdentifier
			 arguments: @[@(streamIdentifier)]];
}

- (void) unregisterStreamIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_UnregisterStreamIdentifier
			 arguments: @[@(streamIdentifier)]];
}

// Buffering stream writes
- (void) putChar: (unichar) ch
		toStream: (unsigned) streamIdentifier {
	[self addOperation: s_PutCharToStream
			 arguments: @[[NSNumber numberWithUnsignedInt: ch]
			 		  							 , @(streamIdentifier)]];
}

- (void) putString: (in bycopy NSString*) string
		  toStream: (unsigned) streamIdentifier  {
	[self addOperation: s_PutStringToStream
			 arguments: @[string
												 , @(streamIdentifier)]];
}

- (void) putData: (in bycopy NSData*) data							// Note: do not pass in mutable data here, as the contents may change unexpectedly
		toStream: (unsigned) streamIdentifier {
	[self addOperation: s_PutDataToStream
			 arguments: @[data
			 		  							 , @(streamIdentifier)]];
}

- (void) setStyle: (unsigned) style
		 onStream: (unsigned) streamIdentifier {
	[self addOperation: s_SetStyle
			 arguments: @[@(style)
			 		  							 , @(streamIdentifier)]];
}


// Hyperlinks on streams
- (void) setHyperlink: (unsigned int) value
			 onStream: (unsigned) streamIdentifier {
	[self addOperation: s_SetHyperlink
			 arguments: @[@(value)
			 		  							 , @(streamIdentifier)]];
}

- (void) clearHyperlinkOnStream: (unsigned) streamIdentifier {
	[self addOperation: s_ClearHyperlinkOnStream
			 arguments: @[@(streamIdentifier)]];
}

// Events

// Requesting events
- (void) requestLineEventsForWindowIdentifier:      (unsigned) windowIdentifier {
	[self addOperation: s_RequestLineEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

- (void) requestCharEventsForWindowIdentifier:      (unsigned) windowIdentifier {
	[self addOperation: s_RequestCharEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

- (void) requestMouseEventsForWindowIdentifier:     (unsigned) windowIdentifier {
	[self addOperation: s_RequestMouseEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

- (void) requestHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_RequestHyperlinkEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

- (void) cancelCharEventsForWindowIdentifier:      (unsigned) windowIdentifier {
	[self addOperation: s_CancelCharEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

- (void) cancelMouseEventsForWindowIdentifier:     (unsigned) windowIdentifier {
	[self addOperation: s_CancelMouseEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

- (void) cancelHyperlinkEventsForWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_CancelHyperlinkEventsForWindowIdentifier
		     arguments: @[@(windowIdentifier)]];
}

/// = Buffer flushing =


- (void) flushToTarget: (id) target {
	// Iterate through the operations
	NSEnumerator* bufferEnum = [operations objectEnumerator];
	NSArray* op;
	
	// Decode each operation in turn using a giant if statements of death
	while (op = [bufferEnum nextObject]) {
		NSString*	opType 	= op[0];
		NSArray* 	args 	= op[1];
			
		// Buffering stream writes
		if ([opType isEqualToString: s_PutCharToStream]) {
			[target putChar: [args[0] unsignedIntValue]
				 toStream: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_PutStringToStream]) {
			[target putString: args[0]
				   toStream: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_PutDataToStream]) {
			[target putData: args[0]
				 toStream: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_SetStyle]) {
			[target setStyle: [args[0] unsignedIntValue]
			      onStream: [args[1] unsignedIntValue]];

		// Graphics
		} else if ([opType isEqualToString: s_FillAreaInWindowWithIdentifier]) {
			[target fillAreaInWindowWithIdentifier: [args[0] unsignedIntValue]
				   			          withColour: args[1]
			                           rectangle: [args[2] rectValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifier]) {
			[target drawImageWithIdentifier: [args[0] unsignedIntValue]
			       inWindowWithIdentifier: [args[1] unsignedIntValue]
			                   atPosition: [args[2] pointValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierInRect]) {
			[target drawImageWithIdentifier: [args[0] unsignedIntValue]
				   inWindowWithIdentifier: [args[1] unsignedIntValue]
								   inRect: [args[2] rectValue]];
		
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierAlign]) {
			[target drawImageWithIdentifier: [args[0] unsignedIntValue]
				   inWindowWithIdentifier: [args[1] unsignedIntValue] 
								alignment: [args[2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierAlignSize]) {
			[target drawImageWithIdentifier: [args[0] unsignedIntValue]
				   inWindowWithIdentifier: [args[1] unsignedIntValue] 
								alignment: [args[2] unsignedIntValue]
									 size: [args[3] sizeValue]];
		
		} else if ([opType isEqualToString: s_BreakFlowInWindowWithIdentifier]) {
			[target breakFlowInWindowWithIdentifier: [args[0] unsignedIntValue]];
		
		// Manipulating windows
		} else if ([opType isEqualToString: s_MoveCursorInWindow]) {
			[target moveCursorInWindow: [args[0] unsignedIntValue]
						 toXposition: [args[1] unsignedIntValue] 
						   yPosition: [args[2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearWindowIdentifier]) {
			[target clearWindowIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearWindowIdentifierWithBackground]) {
			[target clearWindowIdentifier: [args[0] unsignedIntValue]
				   withBackgroundColour: args[1]];
		} else if ([opType isEqualToString: s_SetInputLine]) {
			[target setInputLine: args[0]
		   forWindowIdentifier: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ArrangeWindow]) {
			[target arrangeWindow: [args[0] unsignedIntValue]
						 method: [args[1] unsignedIntValue]
						   size: [args[2] unsignedIntValue]
					  keyWindow: [args[3] unsignedIntValue]];
		
		// Styles
		} else if ([opType isEqualToString: s_SetStyleHint]) {
			[target setStyleHint: [args[0] unsignedIntValue]
					  forStyle: [args[1] unsignedIntValue]
					   toValue: [args[2] unsignedIntValue] 
					windowType: [args[3] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearStyleHint]) {
			[target clearStyleHint: [args[0] unsignedIntValue] 
						forStyle: [args[1] unsignedIntValue] 
					  windowType: [args[2] unsignedIntValue]];
		
		} else if ([opType isEqualToString: s_SetStyleHintStream]) {
			[target setStyleHint: [args[0] unsignedIntValue] 
					   toValue: [args[1] unsignedIntValue] 
					  inStream: [args[2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearStyleHintStream]) {
			[target clearStyleHint: [args[0] unsignedIntValue] 
						inStream: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_SetCustomAttributesStream]) {
			[target setCustomAttributes: args[0] 
							 inStream: [args[1] unsignedIntValue]];
		
		// Hyperlinks on streams
		} else if ([opType isEqualToString: s_SetHyperlink]) {
			[target setHyperlink: [args[0] unsignedIntValue]
					  onStream: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_ClearHyperlinkOnStream]) {
			[target clearHyperlinkOnStream: [args[0] unsignedIntValue]];
		
		// Registering streams
		} else if ([opType isEqualToString: s_RegisterStream]) {
			[target registerStream: args[0] 
				   forIdentifier: [args[1] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RegisterStreamForWindow]) {
			[target registerStreamForWindow: [args[0] unsignedIntValue]
							forIdentifier: [args[1] unsignedIntValue]];
		
		} else if ([opType isEqualToString: s_CloseStreamIdentifier]) {
			[target closeStreamIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_UnregisterStreamIdentifier]) {
			[target unregisterStreamIdentifier: [args[0] unsignedIntValue]];
		
		// Creating the various types of window
		} else if ([opType isEqualToString: s_CreateBlankWindowWithIdentifier]) {
			[target createBlankWindowWithIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreateTextGridWindowWithIdentifier]) {
			[target createTextGridWindowWithIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreateTextWindowWithIdentifier]) {
			[target createTextWindowWithIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreateGraphicsWindowWithIdentifier]) {
			[target createGraphicsWindowWithIdentifier: [args[0] unsignedIntValue]];
		
		// Placing windows in the tree
		} else if ([opType isEqualToString: s_SetRootWindow]) {
			[target setRootWindow: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CreatePairWindowWithIdentifier]) {
			[target createPairWindowWithIdentifier: [args[0] unsignedIntValue] 
									   keyWindow: [args[1] unsignedIntValue] 
									  leftWindow: [args[2] unsignedIntValue] 
									 rightWindow: [args[3] unsignedIntValue] 
										  method: [args[4] unsignedIntValue] 
											size: [args[5] unsignedIntValue]];
		
		// Closing windows
		} else if ([opType isEqualToString: s_CloseWindowIdentifier]) {
			[target closeWindowIdentifier: [args[0] unsignedIntValue]];
		
		// Events
		
		// Requesting events
		} else if ([opType isEqualToString: s_RequestLineEventsForWindowIdentifier]) {
			[target requestLineEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RequestCharEventsForWindowIdentifier]) {
			[target requestCharEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RequestMouseEventsForWindowIdentifier]) {
			[target requestMouseEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_RequestHyperlinkEventsForWindowIdentifier]) {
			[target requestHyperlinkEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		
		} else if ([opType isEqualToString: s_CancelCharEventsForWindowIdentifier]) {
			[target cancelCharEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CancelMouseEventsForWindowIdentifier]) {
			[target cancelMouseEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		} else if ([opType isEqualToString: s_CancelHyperlinkEventsForWindowIdentifier]) {
			[target cancelHyperlinkEventsForWindowIdentifier: [args[0] unsignedIntValue]];
		} else {
			
			NSLog(@"Unknown action type: %@", opType);
		}
	}
}

@end
