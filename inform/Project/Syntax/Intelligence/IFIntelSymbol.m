//
//  IFIntelSymbol.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFIntelSymbol.h"

NSString* IFSectionSymbolType = @"IFSectionSymbolType";

@implementation IFIntelSymbol

// = Initialisation =

- (id) init {
	self = [super init];
	
	if (self) {
		level = -1;			// == Calculate
	}
	
	return self;
}

- (void) dealloc {
	if (name) [name release];
	if (type) [type release];
	
	// ourFile releases us, not the other way around
	
	//if (nextSymbol) [nextSymbol release];
	// if (lastSymbol) [lastSymbol release]; -- not retained when set (ensures that we actually get released!)
	
	[super dealloc];
}

// = Symbol data =

- (NSString*) name {
	return name;
}

- (NSString*) type {
	return type;
}

- (int) level {
	if (level < 0) {
		if (relation == IFSymbolOnLevel)
			return levelDelta;
		
		// Relative level
		if (lastSymbol == nil)
			return levelDelta<0?0:levelDelta;
		
		int realLevel = [lastSymbol level] + levelDelta;
		
		return realLevel<0?0:levelDelta;
	}
	
	return level;
}

- (enum IFSymbolRelation) relation {
	return relation;
}

- (int) levelDelta {
	return levelDelta;
}

- (void) setName: (NSString*) newName {
	if (name) [name release];
	name = [newName copy];
}

- (void) setType: (NSString*) newType {
	if (type) [type release];
	type = [newType copy];
}

- (void) setLevel: (int) newLevel {
	level = newLevel;
}

- (void) setRelation: (enum IFSymbolRelation) newRelation {
	relation = newRelation;
}

- (void) setLevelDelta: (int) newDelta {
	levelDelta = newDelta;
}

// = Debug =

- (NSString*) description {
	NSMutableString* res = [NSMutableString string];
	
	[res appendFormat: @"IFIntelSymbol '%@' - delta %i", name, levelDelta];
	
	return res;
}

// = Our relation to other symbols in the file =

- (IFIntelSymbol*) parent {
	IFIntelSymbol* parent = lastSymbol;
	int myLevel = [self level];
	
	while (parent != nil && [parent level] >= myLevel) {
		parent = parent->lastSymbol;
	}
	
	return parent;
}

- (IFIntelSymbol*) child {
	IFIntelSymbol* child = nextSymbol;
	
	if (child == nil) return nil;
	if ([child level] > [self level]) return child;
	
	return nil;
}

- (IFIntelSymbol*) sibling {
	IFIntelSymbol* sibling = nextSymbol;
	int myLevel = [self level];
	
	while (sibling != nil && [sibling level] > myLevel) sibling = sibling->nextSymbol;
		
	if (sibling == nil) return nil;
	if ([sibling level] == myLevel) return sibling;
	
	if ([sibling level] < myLevel) {
		if ([sibling parent] == [self parent]) return sibling;
	}
	
	return nil;
}

- (IFIntelSymbol*) previousSibling {
	IFIntelSymbol* sibling = lastSymbol;
	int myLevel = [self level];
	
	while (sibling != nil && [sibling level] > myLevel) sibling = sibling->lastSymbol;
	
	if (sibling == nil) return nil;
	if ([sibling level] == [self level]) return sibling;
	
	return nil;
}

- (IFIntelSymbol*) nextSymbol {
	return nextSymbol;
}

- (IFIntelSymbol*) lastSymbol {
	return lastSymbol;
}

// = NSCoding =

// (This is required in order to use these objects in a menu, though is not especially useful in general)

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject: name
				   forKey: @"name"];
	[encoder encodeObject: type
				   forKey: @"type"];
	[encoder encodeInt: level
				forKey: @"level"];
	[encoder encodeInt: relation
				forKey: @"relation"];
	[encoder encodeInt: levelDelta
				forKey: @"levelDelta"];
	[encoder encodeObject: nextSymbol
				   forKey: @"nextSymbol"];
	[encoder encodeObject: lastSymbol
				   forKey: @"lastSymbol"];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		name = [[decoder decodeObjectForKey: @"name"] retain];
		type = [[decoder decodeObjectForKey: @"type"] retain];
		level = [decoder decodeIntForKey: @"level"];
		relation = [decoder decodeIntForKey: @"relation"];
		levelDelta = [decoder decodeIntForKey: @"levelDelta"];
		
		// No point in loading these, as we can't retain them!
		//nextSymbol = [decoder decodeObjectForKey: @"nextSymbol"];
		//lastSymbol = [decoder decodeObjectForKey: @"lastSymbol"];
	}
	
	return self;
}

@end
