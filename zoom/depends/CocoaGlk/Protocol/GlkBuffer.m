//
//  GlkBuffer.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkBuffer.h"

#define GlkBigBuffer 256

#pragma mark - Strings for actions

#pragma mark Windows

// Creating the various types of window
static NSString* const s_CreateBlankWindowWithIdentifier			= @"CBWI";
static NSString* const s_CreateTextGridWindowWithIdentifier			= @"CTGW";
static NSString* const s_CreateTextWindowWithIdentifier 			= @"CTWI";
static NSString* const s_CreateGraphicsWindowWithIdentifier 		= @"CGWI";

// Placing windows in the tree
static NSString* const s_SetRootWindow								= @"WSRW";
static NSString* const s_CreatePairWindowWithIdentifier				= @"CPWI";

// Closing windows
static NSString* const s_CloseWindowIdentifier 						= @"CLWI";

// Manipulating windows
static NSString* const s_MoveCursorInWindow 						= @"MCIW";
static NSString* const s_ClearWindowIdentifier 						= @"WINC";
static NSString* const s_ClearWindowIdentifierWithBackground 		= @"WIBC";
static NSString* const s_SetInputLine 								= @"WSIL";
static NSString* const s_ArrangeWindow 								= @"WARR";

// Styles
static NSString* const s_SetStyleHint 								= @"ISSH";
static NSString* const s_ClearStyleHint 							= @"ICSH";

static NSString* const s_SetStyleHintStream 						= @"SSSH";
static NSString* const s_ClearStyleHintStream 						= @"SCSH";
static NSString* const s_SetCustomAttributesStream 					= @"SSCA";

// Graphics
static NSString* const s_FillAreaInWindowWithIdentifier 			= @"GFAW";
static NSString* const s_DrawImageWithIdentifier 					= @"GDIP";
static NSString* const s_DrawImageWithIdentifierInRect 				= @"GDIR";

static NSString* const s_DrawImageWithIdentifierAlign 				= @"GDIA";
static NSString* const s_DrawImageWithIdentifierAlignSize 			= @"GDIS";

static NSString* const s_BreakFlowInWindowWithIdentifier 			= @"GBFW";

#pragma mark Streams

// Registering streams
static NSString* const s_RegisterStream 							= @"SRSS";
static NSString* const s_RegisterStreamForWindow 					= @"SRSW";

static NSString* const s_CloseStreamIdentifier 						= @"SCSI";
static NSString* const s_UnregisterStreamIdentifier 				= @"SUSI";	// If the stream is closed immediately

// Buffering stream writes
static NSString* const s_PutCharToStream 							= @"SPCH";
static NSString* const s_PutStringToStream 							= @"SPST";
static NSString* const s_PutDataToStream 							= @"SPDA";
static NSString* const s_SetStyle 									= @"SSSS";

// Hyperlinks on streams
static NSString* const s_SetHyperlink 								= @"SHYS";
static NSString* const s_ClearHyperlinkOnStream 					= @"SCLH";

#pragma mark Events

// Requesting events
static NSString* const s_RequestLineEventsForWindowIdentifier 		= @"ERLE";
static NSString* const s_RequestCharEventsForWindowIdentifier		= @"ERCE";
static NSString* const s_RequestMouseEventsForWindowIdentifier		= @"ERME";
static NSString* const s_RequestHyperlinkEventsForWindowIdentifier	= @"ERHE";

static NSString* const s_CancelCharEventsForWindowIdentifier 		= @"ECCE";
static NSString* const s_CancelMouseEventsForWindowIdentifier 		= @"ECME";
static NSString* const s_CancelHyperlinkEventsForWindowIdentifier 	= @"ECHE";

@implementation GlkBuffer

#pragma mark - Initialisation

- (id) init {
	self = [super init];
	
	if (self) {
		operations = [[NSMutableArray alloc] init];
	}
	
	return self;
}

#pragma mark - Buffering

static NSString* stringFromOp(NSArray* op) {
	NSString* opType = [op objectAtIndex: 0];
	
	if ([opType isEqualToString: s_PutCharToStream]) {
		unichar ch = [[[op objectAtIndex: 1] objectAtIndex: 0] unsignedShortValue];
		
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
		
		NSInteger	opPos 		= [operations count] - 1;
		NSArray*	lastOp 		= [operations lastObject];
		int			stream=0, lastStream=0;
		
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
				newData = [oldData mutableCopy];
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

#pragma mark - NSCoding

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	if (self) {
		id decoded;
		if (coder.allowsKeyedCoding) {
			decoded = [coder decodeObjectOfClasses: [NSSet setWithObjects: [NSArray class], [NSNumber class], [NSString class], [NSColor class], [NSValue class], [NSData class], nil] forKey: @"Operations"];
		} else {
			decoded = [coder decodeObject];
		}
		operations = [[NSMutableArray alloc] initWithArray: decoded
												 copyItems: NO];
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	if (coder.allowsKeyedCoding) {
		[coder encodeObject: operations forKey: @"Operations"];
	} else {
		[coder encodeObject: operations];
	}
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

#ifndef COCOAGLK_IPHONE
- (id)replacementObjectForPortCoder:(NSPortCoder *)encoder {
	// This ensures that when we're passed in a bycopy way, we get passed as an actual copy and not a NSDistantObject
	// (which would kind of defeat the whole purpose of the buffer in the first place)
	if ([encoder isBycopy]) return self;
    return [super replacementObjectForPortCoder:encoder];	
}
#endif

#pragma mark - NSCopying

- (id) copyWithZone: (NSZone*) zone {
	GlkBuffer* copy = [[GlkBuffer allocWithZone: zone] init];
	
	copy->operations = [[NSMutableArray alloc] initWithArray: operations
												   copyItems: YES];
	
	return copy;
}

#pragma mark - Method invocations

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
			 arguments: @[@(identifier),
						  @(keyIdentifier),
						  @(leftIdentifier),
						  @(rightIdentifier),
						  @(method),
						  @(size)]];
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
			 arguments: @[@(identifier),
						  @(xpos),
						  @(ypos)]];
}

- (void) clearWindowIdentifier: (glui32) identifier {
	[self addOperation: s_ClearWindowIdentifier
			 arguments: @[@(identifier)]];
}

- (void) clearWindowIdentifier: (glui32) identifier
		  withBackgroundColour: (in bycopy GlkColor*) bgColour {
	[self addOperation: s_ClearWindowIdentifierWithBackground
			 arguments: @[@(identifier),
						  bgColour]];
}

- (void) setInputLine: (in bycopy NSString*) inputLine
  forWindowIdentifier: (unsigned) windowIdentifier {
	[self addOperation: s_SetInputLine
			 arguments: @[inputLine,
						  @(windowIdentifier)]];
}

- (void) arrangeWindow: (glui32) identifier
				method: (glui32) method
				  size: (glui32) size
			 keyWindow: (glui32) keyIdentifier {
	[self addOperation: s_ArrangeWindow
			 arguments: @[@(identifier),
						  @(method),
						  @(size),
						  @(keyIdentifier)]];
}

// Styles
- (void) setStyleHint: (glui32) hint
			 forStyle: (glui32) style
			  toValue: (glsi32) value
		   windowType: (glui32) wintype {
	[self addOperation: s_SetStyleHint
			 arguments: @[@(hint),
						  @(style),
						  @(value),
						  @(wintype)]];
}

- (void) clearStyleHint: (glui32) hint
			   forStyle: (glui32) style
			 windowType: (glui32) wintype {
	[self addOperation: s_ClearStyleHint
			 arguments: @[@(hint),
						  @(style),
						  @(wintype)]];
}

- (void) setStyleHint: (glui32) hint
			  toValue: (glsi32) value
			 inStream: (glui32) streamIdentifier {
	[self addOperation: s_SetStyleHintStream
			 arguments: @[@(hint),
						  @(value),
						  @(streamIdentifier)]];
}

- (void) clearStyleHint: (glui32) hint
			   inStream: (glui32) streamIdentifier {
	[self addOperation: s_ClearStyleHintStream
			 arguments: @[@(hint),
						  @(streamIdentifier)]];
}

- (void) setCustomAttributes: (NSDictionary*) attributes
					inStream: (glui32) streamIdentifier {
	[self addOperation: s_SetCustomAttributesStream
			 arguments: @[attributes,
						  @(streamIdentifier)]];
}

// Graphics
- (void) fillAreaInWindowWithIdentifier: (unsigned) identifier
							 withColour: (in bycopy GlkColor*) color
							  rectangle: (GlkRect) windowArea {
	[self addOperation: s_FillAreaInWindowWithIdentifier
			 arguments: @[@(identifier),
						  color,
						  @(windowArea)]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					  atPosition: (GlkPoint) position {
	[self addOperation: s_DrawImageWithIdentifier
			 arguments: @[@(imageIdentifier),
						  @(windowIdentifier),
						  @(position)]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
						  inRect: (GlkRect) imageRect {
	[self addOperation: s_DrawImageWithIdentifierInRect
			 arguments: @[@(imageIdentifier),
						  @(windowIdentifier),
						  @(imageRect)]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment {
	[self addOperation: s_DrawImageWithIdentifierAlign
			 arguments: @[@(imageIdentifier),
						  @(windowIdentifier),
						  @(alignment)]];
}

- (void) drawImageWithIdentifier: (unsigned) imageIdentifier
		  inWindowWithIdentifier: (unsigned) windowIdentifier
					   alignment: (unsigned) alignment
							size: (GlkCocoaSize) imageSize {
	[self addOperation: s_DrawImageWithIdentifierAlignSize
			 arguments: @[@(imageIdentifier),
						  @(windowIdentifier),
						  @(alignment),
						  @(imageSize)]];
}

- (void) breakFlowInWindowWithIdentifier: (unsigned) identifier {
	[self addOperation: s_BreakFlowInWindowWithIdentifier
			 arguments: @[@(identifier)]];
}

// Streams

// Registering streams
- (void) registerStream: (in byref id<GlkStream>) stream
		  forIdentifier: (unsigned) streamIdentifier  {
	[self addOperation: s_RegisterStream
			 arguments: @[stream,
						  @(streamIdentifier)]];
}

- (void) registerStreamForWindow: (unsigned) windowIdentifier
				   forIdentifier: (unsigned) streamIdentifier {
	[self addOperation: s_RegisterStreamForWindow
			 arguments: @[@(windowIdentifier),
						  @(streamIdentifier)]];
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
			 arguments: @[[NSNumber numberWithUnsignedShort: ch],
						  @(streamIdentifier)]];
}

- (void) putString: (in bycopy NSString*) string
		  toStream: (unsigned) streamIdentifier  {
	[self addOperation: s_PutStringToStream
			 arguments: @[string,
						  @(streamIdentifier)]];
}

- (void) putData: (in bycopy NSData*) data							// Note: do not pass in mutable data here, as the contents may change unexpectedly
		toStream: (unsigned) streamIdentifier {
	[self addOperation: s_PutDataToStream
			 arguments: @[data,
						  @(streamIdentifier)]];
}

- (void) setStyle: (unsigned) style
		 onStream: (unsigned) streamIdentifier {
	[self addOperation: s_SetStyle
			 arguments: @[@(style),
						  @(streamIdentifier)]];
}


// Hyperlinks on streams
- (void) setHyperlink: (unsigned int) value
			 onStream: (unsigned) streamIdentifier {
	[self addOperation: s_SetHyperlink
			 arguments: @[@(value),
						  @(streamIdentifier)]];
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

#pragma mark - Buffer flushing


- (void) flushToTarget: (id<GlkBuffer>) target {
	// Iterate through the operations
	NSEnumerator* bufferEnum = [operations objectEnumerator];
	
	// Decode each operation in turn using a giant if statements of death
	for (NSArray* op in bufferEnum) {
		NSString*	opType 	= [op objectAtIndex: 0];
		NSArray* 	args 	= [op objectAtIndex: 1];
			
		// Buffering stream writes
		if ([opType isEqualToString: s_PutCharToStream]) {
			[target putChar: [[args objectAtIndex: 0] unsignedShortValue]
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
			GlkRect aRect;
#ifdef COCOAGLK_IPHONE
			aRect = [[args objectAtIndex: 2] CGRectValue];
#else
			aRect = [[args objectAtIndex: 2] rectValue];
#endif
			[target fillAreaInWindowWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   			          withColour: [args objectAtIndex: 1]
			                           rectangle: aRect];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifier]) {
			GlkPoint aPoint;
#ifdef COCOAGLK_IPHONE
			aPoint = [[args objectAtIndex: 2] CGPointValue];
#else
			aPoint = [[args objectAtIndex: 2] pointValue];
#endif
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
			       inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue]
			                   atPosition: aPoint];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierInRect]) {
			GlkRect aRect;
#ifdef COCOAGLK_IPHONE
			aRect = [[args objectAtIndex: 2] CGRectValue];
#else
			aRect = [[args objectAtIndex: 2] rectValue];
#endif
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue]
								   inRect: aRect];
		
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierAlign]) {
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue] 
								alignment: [[args objectAtIndex: 2] unsignedIntValue]];
		} else if ([opType isEqualToString: s_DrawImageWithIdentifierAlignSize]) {
			GlkCocoaSize aSize;
#ifdef COCOAGLK_IPHONE
			aSize = [[args objectAtIndex: 3] CGSizeValue];
#else
			aSize = [[args objectAtIndex: 3] sizeValue];
#endif
			[target drawImageWithIdentifier: [[args objectAtIndex: 0] unsignedIntValue]
				   inWindowWithIdentifier: [[args objectAtIndex: 1] unsignedIntValue] 
								alignment: [[args objectAtIndex: 2] unsignedIntValue]
									 size: aSize];
		
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
