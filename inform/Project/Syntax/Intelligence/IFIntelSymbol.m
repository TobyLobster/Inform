//
//  IFIntelSymbol.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFIntelSymbol.h"

NSString* IFSectionSymbolType = @"IFSectionSymbolType";

@implementation IFIntelSymbol {
    // Our data
    NSString* name;							// Name of the symbol (as displayed in the index)
    NSString* type;							// Type of the symbol (see above)
    int level;								// Level of the symbol in the tree (calculated)
    enum IFSymbolRelation relation;			// If IFSymbolDeltaLevel, level is relative to the level of the preceding symbol
    int levelDelta;							// If relation is IFSymbolDelta, the difference in levels, otherwise the absolute level

    // The file we're stored in
    IFIntelFile* ourFile;					// The IntelFile that owns this symbol

    // Our relation in the list of symbols
}

// = Initialisation =

- (instancetype) init {
	self = [super init];
	
	if (self) {
		level = -1;			// == Calculate
	}
	
	return self;
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
		if (_lastSymbol == nil)
			return levelDelta<0?0:levelDelta;
		
		int realLevel = [_lastSymbol level] + levelDelta;
		
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
	name = [newName copy];
}

- (void) setType: (NSString*) newType {
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
	IFIntelSymbol* parent = _lastSymbol;
	int myLevel = [self level];
	
	while (parent != nil && [parent level] >= myLevel) {
		parent = parent->_lastSymbol;
	}
	
	return parent;
}

- (IFIntelSymbol*) child {
	IFIntelSymbol* child = _nextSymbol;
	
	if (child == nil) return nil;
	if ([child level] > [self level]) return child;
	
	return nil;
}

- (IFIntelSymbol*) sibling {
	IFIntelSymbol* sibling = _nextSymbol;
	int myLevel = [self level];
	
	while (sibling != nil && [sibling level] > myLevel) sibling = sibling->_nextSymbol;
		
	if (sibling == nil) return nil;
	if ([sibling level] == myLevel) return sibling;
	
	if ([sibling level] < myLevel) {
		if ([sibling parent] == [self parent]) return sibling;
	}
	
	return nil;
}

- (IFIntelSymbol*) previousSibling {
	IFIntelSymbol* sibling = _lastSymbol;
	int myLevel = [self level];
	
	while (sibling != nil && [sibling level] > myLevel) sibling = sibling->_lastSymbol;
	
	if (sibling == nil) return nil;
	if ([sibling level] == [self level]) return sibling;
	
	return nil;
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
	[encoder encodeObject: _nextSymbol
				   forKey: @"nextSymbol"];
	[encoder encodeObject: _lastSymbol
				   forKey: @"lastSymbol"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		name = [decoder decodeObjectForKey: @"name"];
		type = [decoder decodeObjectForKey: @"type"];
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
