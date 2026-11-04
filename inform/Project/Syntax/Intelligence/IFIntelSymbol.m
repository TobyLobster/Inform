//
//  IFIntelSymbol.m
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFIntelSymbol.h"

NSString* const IFSectionSymbolType = @"IFSectionSymbolType";

@implementation IFIntelSymbol {
    // Our data
    /// Name of the symbol (as displayed in the index)
    NSString* name;
    /// Type of the symbol (see above)
    NSString* type;
    /// Level of the symbol in the tree (calculated)
    int level;
    /// If \c IFSymbolDeltaLevel , level is relative to the level of the preceding symbol
    IFSymbolRelation relation;
    /// If \c relation is \c IFSymbolDelta , the difference in levels, otherwise the absolute level
    int levelDelta;

    // The file we're stored in
    /// The \c IntelFile that owns this symbol
    IFIntelFile* ourFile;
}

#pragma mark - Initialisation

- (instancetype) init {
	self = [super init];
	
	if (self) {
		level = -1;			// == Calculate
	}
	
	return self;
}


#pragma mark - Symbol data

@synthesize name;
@synthesize type;
@synthesize level;

- (int) level {
	if (level < 0) {
		if (relation == IFSymbolOnLevel)
			return levelDelta;
		
		// Relative level
		if (lastSymbol == nil)
			return levelDelta<0?0:levelDelta;
		
		int realLevel = lastSymbol.level + levelDelta;
		
		return realLevel<0?0:levelDelta;
	}
	
	return level;
}

@synthesize relation;
@synthesize levelDelta;

#pragma mark - Debug

- (NSString*) description {
	NSMutableString* res = [NSMutableString string];
	
	[res appendFormat: @"IFIntelSymbol '%@' - delta %i", name, levelDelta];
	
	return res;
}

#pragma mark - Our relation to other symbols in the file

- (IFIntelSymbol*) parent {
	IFIntelSymbol* parent = lastSymbol;
	int myLevel = self.level;
	
	while (parent != nil && parent.level >= myLevel) {
		parent = parent->lastSymbol;
	}
	
	return parent;
}

- (IFIntelSymbol*) child {
	IFIntelSymbol* child = nextSymbol;
	
	if (child == nil) return nil;
	if (child.level > self.level) return child;
	
	return nil;
}

- (IFIntelSymbol*) sibling {
	IFIntelSymbol* sibling = nextSymbol;
	int myLevel = self.level;
	
	while (sibling != nil && sibling.level > myLevel) sibling = sibling->nextSymbol;
		
	if (sibling == nil) return nil;
	if (sibling.level == myLevel) return sibling;
	
	if (sibling.level < myLevel) {
		if (sibling.parent == self.parent) return sibling;
	}
	
	return nil;
}

- (IFIntelSymbol*) previousSibling {
	IFIntelSymbol* sibling = lastSymbol;
	int myLevel = self.level;
	
	while (sibling != nil && sibling.level > myLevel) sibling = sibling->lastSymbol;
	
	if (sibling == nil) return nil;
	if (sibling.level == self.level) return sibling;
	
	return nil;
}

@synthesize nextSymbol;
@synthesize lastSymbol;

#pragma mark - NSCoding

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

- (instancetype)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
	if (self) {
        name = [decoder decodeObjectOfClass: [NSString class] forKey: @"name"];
		type = [decoder decodeObjectOfClass: [NSString class] forKey: @"type"];
		level = [decoder decodeIntForKey: @"level"];
		relation = [decoder decodeIntForKey: @"relation"];
		levelDelta = [decoder decodeIntForKey: @"levelDelta"];
		
		// No point in loading these, as we can't retain them!
		//nextSymbol = [decoder decodeObjectForKey: @"nextSymbol"];
		//lastSymbol = [decoder decodeObjectForKey: @"lastSymbol"];
	}
	
	return self;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
