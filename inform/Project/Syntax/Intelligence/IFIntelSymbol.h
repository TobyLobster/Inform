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
    /// Delta = the level the symbol is on compared to the preceeding symbol of the same type
	IFSymbolOnLevel = 0,
    /// Delta = number of levels up (or down if negative) for this symbol
	IFSymbolDeltaLevel
};

// Standard symbol types
extern NSString* const IFSectionSymbolType;	// Natural Inform section
// (IMPLEMENT ME: Inform 6 objects, etc)

@class IFIntelFile;

///
/// A single symbol gathered by the 'intelligence'
///
@interface IFIntelSymbol : NSObject<NSCoding> {
@protected
    // Only public to IFIntelFile
    __weak IFIntelSymbol* nextSymbol;
    __weak IFIntelSymbol* lastSymbol;
}

// Only public to IFIntelFile
@property(atomic, weak) IFIntelSymbol* nextSymbol;
@property(atomic, weak) IFIntelSymbol* lastSymbol;

// Symbol data
@property (atomic, copy) NSString *name;
@property (atomic, copy) NSString *type;
@property (nonatomic) int level;
@property (atomic) enum IFSymbolRelation relation;
@property (atomic) int levelDelta;


// (If we're stored in an IFIntelFile, our relation to other symbols in the file)
/// May go down multiple levels
@property (atomic, readonly, strong) IFIntelSymbol *parent;
/// Symbol that comes below us (if there is one)
@property (atomic, readonly, strong) IFIntelSymbol *child;
/// Next symbol on the same level
@property (atomic, readonly, strong) IFIntelSymbol *sibling;
/// Previous symbol on the same level
@property (atomic, readonly, strong) IFIntelSymbol *previousSibling;

/// Next symbol (nearest)
- (IFIntelSymbol*) nextSymbol;
/// Previous symbol (nearest)
- (IFIntelSymbol*) lastSymbol;

@end
