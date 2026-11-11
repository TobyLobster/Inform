//
//  IFIntelSymbol.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Our relationship to the preceding symbol in the file
typedef NS_ENUM(int, IFSymbolRelation) {
    /// Delta = the level the symbol is on compared to the preceeding symbol of the same type
	IFSymbolOnLevel = 0,
    /// Delta = number of levels up (or down if negative) for this symbol
	IFSymbolDeltaLevel
};

NS_ASSUME_NONNULL_BEGIN

// Standard symbol types
static NSString* const IFSectionSymbolType = @"IFSectionSymbolType"; // Natural Inform section
// (IMPLEMENT ME: Inform 6 objects, etc)

@class IFIntelFile;

///
/// A single symbol gathered by the 'intelligence'
///
@interface IFIntelSymbol : NSObject<NSSecureCoding>

// Only public to IFIntelFile
/// Next symbol (nearest)
@property(nonatomic, weak, nullable) IFIntelSymbol* nextSymbol;
/// Previous symbol (nearest)
@property(nonatomic, weak, nullable) IFIntelSymbol* lastSymbol;

// Symbol data
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic) int level;
@property (nonatomic) IFSymbolRelation relation;
@property (nonatomic) int levelDelta;


// (If we're stored in an IFIntelFile, our relation to other symbols in the file)
/// May go down multiple levels
@property (nonatomic, readonly, strong, nullable) IFIntelSymbol *parent;
/// Symbol that comes below us (if there is one)
@property (nonatomic, readonly, strong, nullable) IFIntelSymbol *child;
/// Next symbol on the same level
@property (nonatomic, readonly, strong, nullable) IFIntelSymbol *sibling;
/// Previous symbol on the same level
@property (nonatomic, readonly, strong, nullable) IFIntelSymbol *previousSibling;

@end

NS_ASSUME_NONNULL_END
