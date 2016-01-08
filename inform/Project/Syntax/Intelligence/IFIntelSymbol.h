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
@interface IFIntelSymbol : NSObject<NSCoding>

// Only public to IFIntelFile
@property(atomic, strong) IFIntelSymbol* nextSymbol;
@property(atomic, strong) IFIntelSymbol* lastSymbol;

// Symbol data
@property (atomic, copy) NSString *name;
@property (atomic, copy) NSString *type;
@property (atomic) int level;
@property (atomic) enum IFSymbolRelation relation;
@property (atomic) int levelDelta;


// (If we're stored in an IFIntelFile, our relation to other symbols in the file)
@property (atomic, readonly, strong) IFIntelSymbol *parent;             // May go down multiple levels
@property (atomic, readonly, strong) IFIntelSymbol *child;              // Symbol that comes below us (if there is one)
@property (atomic, readonly, strong) IFIntelSymbol *sibling;			// Next symbol on the same level
@property (atomic, readonly, strong) IFIntelSymbol *previousSibling;	// Previous symbol on the same level

- (IFIntelSymbol*) nextSymbol;		// Next symbol (nearest)
- (IFIntelSymbol*) lastSymbol;		// Previous symbol (nearest)

@end
