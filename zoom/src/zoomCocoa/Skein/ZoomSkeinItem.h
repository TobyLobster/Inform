//
//  ZoomSkeinItem.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

// Commentary comparison results
typedef enum ZoomSkeinComparison {
	ZoomSkeinNoResult,										// One side of the comparison doesn't exist (eg, no commentary for an item)
	ZoomSkeinIdentical,										// Sides are identical
	ZoomSkeinDiffersOnlyByWhitespace,						// Sides are different, but only in terms of whitespace
	ZoomSkeinDifferent,										// Sides are different
	
	ZoomSkeinNotCompared									// (Placeholder: sides have not been compared)
} ZoomSkeinComparison;

// Skein item notifications
extern NSString* ZoomSkeinItemIsBeingReplaced;				// One skein item is being replaced by another
extern NSString* ZoomSkeinItemHasBeenRemovedFromTree;		// A skein item is being removed from the tree (may be associated with the previous)
extern NSString* ZoomSkeinItemHasChanged;					// A skein item has been changed in some way
extern NSString* ZoomSkeinItemHasNewChild;					// A skein item has gained a new child item

// Skein item notification dictionary keys
extern NSString* ZoomSIItem;								// Item the operation applies to
extern NSString* ZoomSIOldItem;								// Previous item, if there is one
extern NSString* ZoomSIOldParent;							// Parent item of an item that's been removed
extern NSString* ZoomSIChild;								// Child item (if relevant)

//
// Represents a single 'knot' in the skein
//
@interface ZoomSkeinItem : NSObject<NSCoding>

// Initialisation
+ (ZoomSkeinItem*) skeinItemWithCommand: (NSString*) command;

- (instancetype) initWithCommand: (NSString*) command NS_DESIGNATED_INITIALIZER;

// Data accessors

// Skein tree
@property (NS_NONATOMIC_IOSONLY, readonly, strong) ZoomSkeinItem *parent;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSSet *children;
- (ZoomSkeinItem*) childWithCommand: (NSString*) command;

- (ZoomSkeinItem*) addChild: (ZoomSkeinItem*) childItem;
- (void)		   removeChild: (ZoomSkeinItem*) childItem;
- (void)		   removeFromParent;

- (BOOL)           hasChild: (ZoomSkeinItem*) child; // Recursive
- (BOOL)           hasChildWithCommand: (NSString*) command; // Not recursive

// Item data
@property (NS_NONATOMIC_IOSONLY, copy) NSString *command; // Command input
@property (NS_NONATOMIC_IOSONLY, copy) NSString *result;  // Command result


// Item state
@property (NS_NONATOMIC_IOSONLY) BOOL temporary;			// Whether or not this item has been made permanent by saving
@property (NS_NONATOMIC_IOSONLY) int temporaryScore;	// Lower values are more likely to be removed
@property (NS_NONATOMIC_IOSONLY) BOOL played;			// Whether or not this item has actually been played
@property (NS_NONATOMIC_IOSONLY) BOOL changed;			// Whether or not this item's result has changed since this was last played
							// (Automagically updated by setResult:)

- (void) setBranchTemporary: (BOOL) isTemporary;
- (void) increaseTemporaryScore;

// Annotation

// Allows the player to designate certain areas of the skein as having specific annotations and colours
// (So, for example an area can be called 'solution to the maximum mouse melee puzzle')
// Each 'annotation' colours a new area of the skein.
@property (NS_NONATOMIC_IOSONLY, copy) NSString *annotation;

// Commentary

// Could be used by an IDE to store commentary or perhaps the 'ideal' text the game should be
// producing for this item
@property (NS_NONATOMIC_IOSONLY, copy) NSString *commentary;
@property (NS_NONATOMIC_IOSONLY, readonly) ZoomSkeinComparison commentaryComparison;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) ZoomSkeinItem *nextDiff;									// Finds the first item following this one that has a difference

- (ZoomSkeinComparison) forceCommentaryComparison;

// Drawing/sizing
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize commandSize;
- (void) drawCommandAtPosition: (NSPoint) position;
@property (NS_NONATOMIC_IOSONLY, readonly) NSSize annotationSize;
- (void) drawAnnotationAtPosition: (NSPoint) position;

@end
