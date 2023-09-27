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

/// Paseboard type for drag and drop
extern NSString* const IFSkeinItemPboardType;

#pragma mark - "Skein Item"
///
/// Represents a single 'knot' in the skein
///
@interface IFSkeinItem : NSObject<NSSecureCoding, NSPasteboardWriting>

#pragma mark - Initialization
- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithSkein:(IFSkein*) skein command: (NSString*) com NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithCoder: (NSCoder *) decoder NS_DESIGNATED_INITIALIZER;

#pragma mark - Properties
@property (atomic, readonly)          unsigned long   uniqueId;
@property (atomic, strong)            IFSkein *       skein;
@property (nonatomic, weak)           IFSkeinItem *   parent;
@property (atomic, readonly, copy)    NSArray<IFSkeinItem*> *       children;
@property (nonatomic, copy)           NSString *      command;        // Command
@property (nonatomic, copy)           NSString *      actual;         // Latest actual output from the game
@property (nonatomic, copy)           NSString *      ideal;          // The ideal version of the output
@property (nonatomic)                 BOOL            isTestSubItem;  // Is node a result of a "test me" style command?
@property (atomic)                    IFDiffer*       diffCachedResult;       // Differences

@property (atomic, readonly)          unsigned long   reportStateHash;

#pragma mark - Methods
@property (NS_NONATOMIC_IOSONLY, readonly, strong) IFSkeinItem *rootItem;
-(BOOL)             hasDescendant: (IFSkeinItem*) child;                                    // Recursive
- (IFSkeinItem*)    childWithCommand: (NSString*) com isTestSubItem:(BOOL) isTestSubItem;   // Not recursive
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray<IFSkeinItem *> *nonTestChildren;

-(IFSkeinItem*)     addChild: (IFSkeinItem*) childItem;
-(void)             removeFromParent;

+(BOOL)             isTestCommand:(NSString*) command;
-(IFSkeinItem*)     findItemWithNodeId: (unsigned long) skeinNodeId;

#pragma mark - Undo helpers
-(void)             removeFromChildrenArray: (IFSkeinItem*) itemToRemove;
-(void)             addToChildrenArray: (IFSkeinItem*) itemToAdd;
-(void)             setIsTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem;

#pragma mark - Handling prompts
+(NSString*) promptForString: (NSString*) string;
+(NSString*) stringByRemovingPrompt: (NSString*) string;

#pragma mark - Differences
@property (NS_NONATOMIC_IOSONLY, readonly, strong) IFDiffer *differences;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasDifferences;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasBadge;
@property (NS_NONATOMIC_IOSONLY, readonly) BOOL hasIdeal;

#pragma mark - Composing and Decomposing "test me" style nodes
-(IFSkeinItem*) decomposeActual:(NSString*) actual;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) IFSkeinItem *decompose;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *composedActual;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *composedIdeal;

// Cache of command size, used by IFSkeinItemView when laying out
#pragma mark - Command size cache
@property (atomic) BOOL     commandSizeDidChange;
@property (atomic) NSSize   cachedCommandSize;

/// When font size preference changes, force recalculation of command sizes
-(void) forceCommandSizeChangeRecursively;

@end
