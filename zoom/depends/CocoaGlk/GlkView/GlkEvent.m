//
//  GlkEvent.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkEvent.h"


@implementation GlkEvent

// = Initialisation =

- (id) initWithType: (unsigned) newType
   windowIdentifier: (unsigned) newWindowId {
	return [self initWithType: newType
			 windowIdentifier: newWindowId
						 val1: 0 
						 val2: 0];
}

- (id) initWithType: (unsigned) newType
   windowIdentifier: (unsigned) newWindowId
			   val1: (unsigned) newVal1 {
	return [self initWithType: newType
			 windowIdentifier: newWindowId
						 val1: newVal1
						 val2: 0];
}

- (id) initWithType: (unsigned) newType
   windowIdentifier: (unsigned) newWindowId
			   val1: (unsigned) newVal1
			   val2: (unsigned) newVal2 {
	self = [super init];
	
	if (self) {
		type = newType;
		windowId = newWindowId;
		val1 = newVal1;
		val2 = newVal2;
		
		lineInput = nil;
	}
	
	return self;
}

- (void) dealloc {
	[lineInput release]; lineInput = nil;
	
	[super dealloc];
}

- (void) setLineInput: (NSString*) newLineInput {
	[lineInput release];
	lineInput = [newLineInput copy];
}

// = GlkEvent methods =

- (glui32) type {
	return type;
}

- (unsigned) windowIdentifier {
	return windowId;
}

- (glui32) val1 {
	return val1;
}

- (glui32) val2 {
	return val2;
}

- (NSString*) lineInput {
	return lineInput;
}

// = NSCoding methods =

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	if (self) {
		[coder decodeValueOfObjCType: @encode(unsigned) at: &type];
		[coder decodeValueOfObjCType: @encode(unsigned) at: &windowId];
		[coder decodeValueOfObjCType: @encode(unsigned) at: &val1];
		[coder decodeValueOfObjCType: @encode(unsigned) at: &val2];
		
		lineInput = [[coder decodeObject] copy];
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	[coder encodeValueOfObjCType: @encode(unsigned) at: &type];
	[coder encodeValueOfObjCType: @encode(unsigned) at: &windowId];
	[coder encodeValueOfObjCType: @encode(unsigned) at: &val1];
	[coder encodeValueOfObjCType: @encode(unsigned) at: &val2];

	[coder encodeObject: lineInput];
}

@end
