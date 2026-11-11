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

NS_ASSUME_NONNULL_BEGIN

/// Paseboard type for drag and drop
static NSString* const IFSkeinItemPboardType = @"com.inform7.IFSkeinItemPboardType";

#pragma mark - "Skein Item"
///
/// Represents a single 'knot' in the skein
///
NS_SWIFT_UI_ACTOR
@interface IFSkeinItem : NSObject<NSSecureCoding, NSPasteboardWriting>

#pragma mark - Initialization
- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithSkein:(nullable IFSkein*) skein command: (nullable NSString*) com NS_DESIGNATED_INITIALIZER;
-(nullable instancetype) initWithCoder: (NSCoder *) decoder NS_DESIGNATED_INITIALIZER;

#pragma mark - Properties
@property (nonatomic, readonly)       unsigned long   uniqueId;
@property (nonatomic, strong, nullable) IFSkein *     skein;
@property (nonatomic, weak, nullable) IFSkeinItem *   parent;
@property (nonatomic, readonly, copy) NSArray<IFSkeinItem*> *       children;
@property (nonatomic, copy, null_resettable) NSString * command;        // Command
@property (nonatomic, copy, null_resettable) NSString * actual;         // Latest actual output from the game
@property (nonatomic, copy, null_resettable) NSString * ideal;          // The ideal version of the output
@property (nonatomic)                 BOOL            isTestSubItem;  // Is node a result of a "test me" style command?
@property (nonatomic)                 IFDiffer*       diffCachedResult;       // Differences

@property (nonatomic, readonly)       unsigned long   reportStateHash;

#pragma mark - Methods
@property (NS_NONATOMIC_IOSONLY, readonly, strong) IFSkeinItem *rootItem;
-(BOOL)             hasDescendant: (nullable IFSkeinItem*) child;                                    // Recursive
- (nullable IFSkeinItem*) childWithCommand: (NSString*) com isTestSubItem:(BOOL) isTestSubItem;   // Not recursive
@property (NS_NONATOMIC_IOSONLY, readonly, copy, nullable) NSArray<IFSkeinItem *> *nonTestChildren;

-(IFSkeinItem*)     addChild: (IFSkeinItem*) childItem;
-(void)             removeFromParent;

+(BOOL)             isTestCommand:(NSString*) command;
-(nullable IFSkeinItem*) findItemWithNodeId: (unsigned long) skeinNodeId;

#pragma mark - Undo helpers
-(void)             removeFromChildrenArray: (IFSkeinItem*) itemToRemove;
-(void)             addToChildrenArray: (IFSkeinItem*) itemToAdd;
-(void)             setIsTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem;

#pragma mark - Handling prompts
+(NSString*) promptForString: (nullable NSString*) string;
+(NSString*) stringByRemovingPrompt: (nullable NSString*) string;

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
@property (nonatomic) BOOL     commandSizeDidChange;
@property (nonatomic) NSSize   cachedCommandSize;

/// When font size preference changes, force recalculation of command sizes
-(void) forceCommandSizeChangeRecursively;

@end

NS_ASSUME_NONNULL_END
