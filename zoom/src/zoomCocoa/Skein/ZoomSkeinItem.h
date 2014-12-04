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
@interface ZoomSkeinItem : NSObject<NSCoding> {
	ZoomSkeinItem* parent;
	NSMutableSet* children;
	
	NSString*     command;
	NSString*     result;
	
	BOOL temporary;
	int  tempScore;
	
	BOOL played, changed;
	
	NSString* annotation;
	NSString* commentary;
	
	// Cached layout items (text measuring is slow)
	BOOL   commandSizeDidChange;
	NSSize commandSize;
	
	BOOL   annotationSizeDidChange;
	NSSize annotationSize;
	
	// Results of comparing the result to the commentary
	ZoomSkeinComparison commentaryComparison;
}

// Initialisation
+ (ZoomSkeinItem*) skeinItemWithCommand: (NSString*) command;

- (id) initWithCommand: (NSString*) command;

// Data accessors

// Skein tree
- (ZoomSkeinItem*) parent;
- (NSSet*)         children;
- (ZoomSkeinItem*) childWithCommand: (NSString*) command;

- (ZoomSkeinItem*) addChild: (ZoomSkeinItem*) childItem;
- (void)		   removeChild: (ZoomSkeinItem*) childItem;
- (void)		   removeFromParent;

- (BOOL)           hasChild: (ZoomSkeinItem*) child; // Recursive
- (BOOL)           hasChildWithCommand: (NSString*) command; // Not recursive

// Item data
- (NSString*)      command; // Command input
- (NSString*)      result;  // Command result

- (void) setCommand: (NSString*) command;
- (void) setResult:  (NSString*) result;

// Item state
- (BOOL) temporary;			// Whether or not this item has been made permanent by saving
- (int)  temporaryScore;	// Lower values are more likely to be removed
- (BOOL) played;			// Whether or not this item has actually been played
- (BOOL) changed;			// Whether or not this item's result has changed since this was last played
							// (Automagically updated by setResult:)

- (void) setTemporary: (BOOL) isTemporary;
- (void) setBranchTemporary: (BOOL) isTemporary;
- (void) setTemporaryScore: (int) score;
- (void) increaseTemporaryScore;
- (void) setPlayed: (BOOL) played;
- (void) setChanged: (BOOL) changed;

// Annotation

// Allows the player to designate certain areas of the skein as having specific annotations and colours
// (So, for example an area can be called 'solution to the maximum mouse melee puzzle')
// Each 'annotation' colours a new area of the skein.
- (NSString*) annotation;
- (void)      setAnnotation: (NSString*) newAnnotation;

// Commentary

// Could be used by an IDE to store commentary or perhaps the 'ideal' text the game should be
// producing for this item
- (NSString*) commentary;
- (void)      setCommentary: (NSString*) commentary;
- (ZoomSkeinComparison) commentaryComparison;
- (ZoomSkeinItem*) nextDiff;									// Finds the first item following this one that has a difference

// Drawing/sizing
- (NSSize) commandSize;
- (void) drawCommandAtPosition: (NSPoint) position;
- (NSSize) annotationSize;
- (void) drawAnnotationAtPosition: (NSPoint) position;

@end
