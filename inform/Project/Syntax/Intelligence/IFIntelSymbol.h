//
//  IFIntelSymbol.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Our relationship to the preceding symbol in the file
enum IFSymbolRelation {
	IFSymbolOnLevel = 0,		// Delta = the level the symbol is on compared to the preceeding symbol of the same type
	IFSymbolDeltaLevel			// Delta = number of levels up (or down if negative) for this symbol
};

// Standard symbol types
extern NSString* IFSectionSymbolType;	// Natural Inform section
// (IMPLEMENT ME: Inform 6 objects, etc)

@class IFIntelFile;

//
// A single symbol gathered by the 'intelligence'
//
@interface IFIntelSymbol : NSObject<NSCoding> {
	// Our data
	NSString* name;							// Name of the symbol (as displayed in the index)
	NSString* type;							// Type of the symbol (see above)
	int level;								// Level of the symbol in the tree (calculated)
	enum IFSymbolRelation relation;			// If IFSymbolDeltaLevel, level is relative to the level of the preceding symbol
	int levelDelta;							// If relation is IFSymbolDelta, the difference in levels, otherwise the absolute level
	
	// The file we're stored in
	IFIntelFile* ourFile;					// The IntelFile that owns this symbol
	
	// Our relation in the list of symbols
@public
	// Only public to IFIntelFile
	IFIntelSymbol* nextSymbol;
	IFIntelSymbol* lastSymbol;
}

// Symbol data
- (NSString*) name;
- (NSString*) type;
- (int) level;
- (enum IFSymbolRelation) relation;
- (int) levelDelta;

- (void) setName: (NSString*) newName;
- (void) setType: (NSString*) newType;
- (void) setLevel: (int) level;
- (void) setRelation: (enum IFSymbolRelation) relation;
- (void) setLevelDelta: (int) newDelta;

// (If we're stored in an IFIntelFile, our relation to other symbols in the file)
- (IFIntelSymbol*) parent;			// May go down multiple levels
- (IFIntelSymbol*) child;			// Symbol that comes below us (if there is one)
- (IFIntelSymbol*) sibling;			// Next symbol on the same level
- (IFIntelSymbol*) previousSibling;	// Previous symbol on the same level

- (IFIntelSymbol*) nextSymbol;		// Next symbol (nearest)
- (IFIntelSymbol*) lastSymbol;		// Previous symbol (nearest)

@end

#import "IFIntelFile.h"
