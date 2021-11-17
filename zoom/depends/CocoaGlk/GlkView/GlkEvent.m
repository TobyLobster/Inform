//
//  GlkEvent.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 22/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "GlkEvent.h"


@implementation GlkEvent

#pragma mark - Initialisation

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

@synthesize lineInput;

#pragma mark - GlkEvent methods

@synthesize type;
@synthesize windowIdentifier=windowId;
@synthesize val1;
@synthesize val2;

#pragma mark - NSCoding methods

#define LINEINPUTCODINGKEY @"lineInput"
#define TYPECODINGKEY @"type"
#define WINDOWIDCODINGKEY @"windowId"
#define VAL1CODINGKEY @"val1"
#define VAL2CODINGKEY @"val2"

- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	if (self) {
		if (coder.allowsKeyedCoding) {
			type = [coder decodeIntForKey: TYPECODINGKEY];
			windowId = [coder decodeIntForKey: WINDOWIDCODINGKEY];
			val1 = [coder decodeIntForKey: VAL1CODINGKEY];
			val2 = [coder decodeIntForKey: VAL2CODINGKEY];
			
			lineInput = [[coder decodeObjectOfClass: [NSString class] forKey: LINEINPUTCODINGKEY] copy];
		} else {
			[coder decodeValueOfObjCType: @encode(unsigned) at: &type size: sizeof(unsigned)];
			[coder decodeValueOfObjCType: @encode(unsigned) at: &windowId size: sizeof(unsigned)];
			[coder decodeValueOfObjCType: @encode(unsigned) at: &val1 size: sizeof(unsigned)];
			[coder decodeValueOfObjCType: @encode(unsigned) at: &val2 size: sizeof(unsigned)];
			
			lineInput = [[coder decodeObject] copy];
		}
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	if (coder.allowsKeyedCoding) {
		[coder encodeInt: type forKey: TYPECODINGKEY];
		[coder encodeInt: windowId forKey: WINDOWIDCODINGKEY];
		[coder encodeInt: val1 forKey: VAL1CODINGKEY];
		[coder encodeInt: val2 forKey: VAL2CODINGKEY];

		[coder encodeObject: lineInput forKey: LINEINPUTCODINGKEY];
	} else {
		[coder encodeValueOfObjCType: @encode(unsigned) at: &type];
		[coder encodeValueOfObjCType: @encode(unsigned) at: &windowId];
		[coder encodeValueOfObjCType: @encode(unsigned) at: &val1];
		[coder encodeValueOfObjCType: @encode(unsigned) at: &val2];
		
		[coder encodeObject: lineInput];
	}
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

@end
