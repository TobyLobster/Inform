//
//  IFSkeinItem.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>

@class IFSkeinLayoutItem;
@class IFDiffer;
@class IFSkein;

#pragma mark - "Skein Item"
///
/// Represents a single 'knot' in the skein
///
@interface IFSkeinItem : NSObject<NSCoding>

#pragma mark - Initialization
- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithSkein:(IFSkein*) skein command: (NSString*) com;
- (instancetype) initWithSkein:(IFSkein*) skein command: (NSString*) com identifier: (NSUUID*) uuid NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithCoder: (NSCoder *) decoder NS_DESIGNATED_INITIALIZER;

#pragma mark - Properties
@property (atomic, readonly, strong)  NSUUID *        uniqueId;
@property (atomic, strong)            IFSkein *       skein;
@property (nonatomic, weak)           IFSkeinItem *   parent;
@property (atomic, readonly, copy)    NSArray<IFSkeinItem*> *       children;
@property (nonatomic, copy)           NSString *      command;        // Command
@property (nonatomic, copy)           NSString *      actual;         // Latest actual output from the game
@property (nonatomic, copy)           NSString *      ideal;          // The ideal version of the output
@property (nonatomic)                 BOOL            isTestSubItem;  // Is node a result of a "test me" style command?
@property (atomic, readonly)          unsigned long   reportStateHash;

#pragma mark - Methods
-(IFSkeinItem *)    rootItem;
-(BOOL)             hasDescendant: (IFSkeinItem*) child;                                    // Recursive
- (IFSkeinItem*)    childWithCommand: (NSString*) com isTestSubItem:(BOOL) isTestSubItem;   // Not recursive
-(NSArray<IFSkeinItem*> *)        nonTestChildren;

-(IFSkeinItem*)     addChild: (IFSkeinItem*) childItem;
-(void)             removeFromParent;

+(BOOL)             isTestCommand:(NSString*) command;
-(IFSkeinItem*)     findItemWithNodeId: (NSUUID*) skeinNodeId;

#pragma mark - Undo helpers
-(void)             removeFromChildrenArray: (IFSkeinItem*) itemToRemove;
-(void)             addToChildrenArray: (IFSkeinItem*) itemToAdd;
-(void)             setIsTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem;

#pragma mark - Handling prompts
+(NSString*) promptForString: (NSString*) string;
+(NSString*) stringByRemovingPrompt: (NSString*) string;

#pragma mark - Differences
-(IFDiffer*) differences;
-(BOOL) hasDifferences;
-(BOOL) hasBadge;
-(BOOL) hasIdeal;

#pragma mark - Composing and Decomposing "test me" style nodes
-(IFSkeinItem*) decomposeActual:(NSString*) actual;
-(IFSkeinItem*) decompose;
-(NSString*) composedActual;
-(NSString*) composedIdeal;

// Cache of command size, used by IFSkeinItemView when laying out
#pragma mark - Command size cache
@property (atomic) BOOL     commandSizeDidChange;
@property (atomic) NSSize   cachedCommandSize;

/// When font size preference changes, force recalculation of command sizes
-(void) forceCommandSizeChangeRecursively;

@end
