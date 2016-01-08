//
//  ZoomSkeinItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomSkeinItem.h"

// Skein item notifications
NSString* ZoomSkeinItemIsBeingReplaced = @"ZoomSkeinItemIsBeingReplaced";
NSString* ZoomSkeinItemHasBeenRemovedFromTree = @"ZoomSkeinItemHasBeenRemovedFromTree";	
NSString* ZoomSkeinItemHasChanged = @"ZoomSkeinItemHasChanged";
NSString* ZoomSkeinItemHasNewChild = @"ZoomSkeinItemHasNewChild";

// Skein item notification dictionary keys
NSString* ZoomSIItem = @"ZoomSIItem";
NSString* ZoomSIOldItem = @"ZoomSIOldItem";
NSString* ZoomSIOldParent = @"ZoomSIOldParent";
NSString* ZoomSIChild = @"ZoomSIChild";

@implementation ZoomSkeinItem {
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

// = Initialisation =

static NSString* convertCommand(NSString* command) {
	if (command == nil) return nil;
	
	unichar* uniBuf = malloc(sizeof(unichar)*[command length]);
	[command getCharacters: uniBuf];
	
	BOOL needsChange = NO;
	int x;
	int spaces = 0;
	
	for (x=0; x<[command length]; x++) {
		if (uniBuf[x] < 32) {
			needsChange = YES;
			uniBuf[x] = ' ';
		}
		
		if (uniBuf[x] == 32) {
			spaces++;
		} else {
			spaces = 0;
		}
	}
	
	if (needsChange) {
		command = [NSString stringWithCharacters: uniBuf
										  length: [command length] - spaces];
	}
	
	free(uniBuf);
	
	return command;
}

+ (ZoomSkeinItem*) skeinItemWithCommand: (NSString*) com {
	return [[[[self class] alloc] initWithCommand: com] autorelease];
}

- (instancetype) initWithCommand: (NSString*) com {
	self = [super init];
	
	if (self) {
		command = [convertCommand(com) copy];
		result  = nil;
		
		parent = nil;
		children = [[NSMutableSet alloc] init];
		
		temporary = YES;
		tempScore = 0;
		played    = NO;
		changed   = YES;
        commentaryComparison = ZoomSkeinNoResult;

		annotation = nil;

		annotationSizeDidChange = commandSizeDidChange = YES;
	}
	
	return self;
}

- (instancetype) init {
	return [self initWithCommand: nil];
}

- (void) dealloc {
	// First, mark the old items as having no parent
	NSMutableArray* childrenToDestroy = [NSMutableArray array];
	NSEnumerator* objEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	while (child = [objEnum nextObject]) {
		[childrenToDestroy addObject: child];
	}
	
	// Luke, I am your father
	[childrenToDestroy makeObjectsPerformSelector: @selector(removeFromParent)];
	
	// Then just release everything
	[children release];

	if (command)	[command release];
	if (result)		[result release];
	if (annotation) [annotation release];
	
	// NOOOOOOO
	[super dealloc];
}

// **** Notification convienience functions ****

- (void) itemIsBeingReplacedBy: (ZoomSkeinItem*) item {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomSkeinItemIsBeingReplaced
														object: self
													  userInfo: @{ZoomSIItem: item,
														  ZoomSIOldItem: self}];
}

- (void) itemHasBeenRemovedFromTree {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomSkeinItemHasBeenRemovedFromTree
														object: self
													  userInfo: @{ZoomSIItem: self}];
}

- (void) itemHasNewChild: (ZoomSkeinItem*) newChild {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomSkeinItemHasNewChild
														object: self
													  userInfo: @{ZoomSIItem: self,
														  ZoomSIChild: newChild}];
}

- (void) itemHasChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomSkeinItemHasChanged
														object: self
													  userInfo: @{ZoomSIItem: self}];
}

// **** Data accessors ****

// = Skein tree =

- (void) setParent: (ZoomSkeinItem*) newParent {
	parent = newParent;
}

- (ZoomSkeinItem*) parent {
	return parent;
}

- (NSSet*) children {
	return children;
}

- (ZoomSkeinItem*) childWithCommand: (NSString*) com {
	NSEnumerator* objEnum = [children objectEnumerator];
	ZoomSkeinItem* skeinItem;
	
	while (skeinItem = [objEnum nextObject]) {
		if ([[skeinItem command] isEqualToString: com]) return skeinItem;
	}
	
	return nil;
}

- (void) mergeWith: (ZoomSkeinItem*) newItem {
	// Merges this item with another
	NSEnumerator* objEnum = [[newItem children] objectEnumerator];
	ZoomSkeinItem* childItem;
	
	while (childItem = [objEnum nextObject]) {
		ZoomSkeinItem* oldChild = [self childWithCommand: [childItem command]];
		
		// Same reasoning as addChild: - this saves us a message call, which might allow us to deal with deeper skeins
		if (oldChild == nil) {
			[self addChild: childItem];
		} else {
			[oldChild mergeWith: childItem];
		}
	}
}

- (ZoomSkeinItem*) addChild: (ZoomSkeinItem*) childItem {
	ZoomSkeinItem* oldChild = [self childWithCommand: [childItem command]];
	
	if (oldChild != nil) {
		// Merge if this child item already exists
		[oldChild mergeWith: childItem];
		
		// Set certain flags to the same as the new item
		if ([childItem result]) [oldChild setResult: [childItem result]];
		if ([childItem annotation]) [oldChild setAnnotation: [childItem annotation]];
		if ([childItem commentary]) [oldChild setCommentary: [childItem commentary]];
		
		if (![childItem temporary]) [oldChild setTemporary: NO];
		[oldChild setPlayed: [childItem played]];
        [oldChild setChanged: [childItem changed]];

		// 'New' item is the old one
		[childItem itemIsBeingReplacedBy: oldChild];
		
		return oldChild;
	} else {
		[[childItem retain] autorelease];
		[childItem removeFromParent];
		
		// Otherwise, just add the new item
		[childItem setParent: self];
		[children addObject: childItem];
		
		// 'new' item is the child item
		[self itemHasNewChild: childItem];
		
		return childItem;
	}
}

- (void) removeChild: (ZoomSkeinItem*) childItem {
	if ([childItem parent] != self) return;

	[[childItem retain] autorelease];
	
	[childItem setParent: nil];
	[children removeObject: childItem];

	[childItem itemHasBeenRemovedFromTree];
}

- (void) removeFromParent {
	if (parent) {
		[parent removeChild: self];
	}
}

- (BOOL) hasChild: (ZoomSkeinItem*) item {
	if (item == self) return YES;
	//if ([children containsObject: child]) return YES;
	
	NSEnumerator* childEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	
	while (child = [childEnum nextObject]) {
		if ([child hasChild: item]) return YES;
	}
	
	return NO;
}

- (BOOL) hasChildWithCommand: (NSString*) theCommand {
	NSEnumerator* childEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	
	if (theCommand == nil) theCommand = @"";
	
	while (child = [childEnum nextObject]) {
		NSString* childCommand = [child command];
		if (childCommand == nil) childCommand = @"";
		
		if ([childCommand isEqualToString: theCommand]) return YES;
	}
	
	return NO;
}

// = Item data =

- (NSString*) command {
	return [[command copy] autorelease];
}

- (NSString*) result {
	return [[result copy] autorelease];
}

- (void) setCommand: (NSString*) newCommand {
	if ([newCommand isEqualToString: command]) return;			// Nothing to do
	
	if (command) [command release];
	command = nil;
	if (![newCommand isEqualToString: command]) commandSizeDidChange = YES;
	if (newCommand) command = [convertCommand(newCommand) copy];
	
	[self itemHasChanged];
}

- (void) setResult: (NSString*) newResult {
	if (![result isEqualTo: newResult]) {
		[self setChanged: YES];
	} else {
		[self setChanged: NO];
		return;							// Nothing else to do
	}
	
	if (result) [result release];
	result = nil;
	if (newResult) result = [newResult copy];
	
	commentaryComparison = ZoomSkeinNotCompared;
	
	[self itemHasChanged];
}

// = Item state =

- (BOOL) temporary {
	return temporary;
}

- (int)  temporaryScore {
	return tempScore;
}

- (BOOL) played {
	return played;
}

- (BOOL) changed {
	return changed;
}

- (void) setTemporary: (BOOL) isTemporary {
	temporary = isTemporary;
	
	ZoomSkeinItem* p = [self parent];
	
	// Also applies to parent items if set to 'NO'
	if (!isTemporary) {
		while (p != nil && [p parent] != nil) {
			if (![p temporary]) break;
			[p setTemporary: NO];
			
			p = [p parent];
		}
	} else {
		// Applies to child items if set to 'YES'
		NSEnumerator* childEnum = [[self children] objectEnumerator];
		ZoomSkeinItem* child;
		
		while (child = [childEnum nextObject]) {
			if (![child temporary]) [child setTemporary: YES];
		}
	}
	
	[self itemHasChanged];
}

- (void) setBranchTemporary: (BOOL) isTemporary {
	ZoomSkeinItem* lowerItem = self;
	if (!isTemporary) {
		// Find the lowermost item in this branch (ie, set this entire branch as temporary)		
		while ([[lowerItem children] count] == 1) {
			lowerItem = [[lowerItem children] allObjects][0];
		}
	} else {
		// Find the uppermost item in this branch (ie, set this entire branch as not temporary)
		while ([lowerItem parent] != nil && [[[lowerItem parent] children] count] == 1) {
			lowerItem = [lowerItem parent];
		}
	}
	
	[lowerItem setTemporary: isTemporary];
}

static int currentScore = 1;

- (void) zoomSetTemporaryScore {
	tempScore = currentScore;
}

- (void) setTemporaryScore: (int) score {
	tempScore = score;
}

- (void) increaseTemporaryScore {
	tempScore = currentScore++;
	
	// Also set the parent's scores
	ZoomSkeinItem* item = parent;
	while (item != nil) {
		[item zoomSetTemporaryScore];
		item = [item parent];
	}
}

- (void) setPlayed: (BOOL) newPlayed {
	BOOL oldPlayed = played;
	played = newPlayed;
	
	if (oldPlayed != newPlayed) [self itemHasChanged];
}

- (void) setChanged: (BOOL) newChanged {
	BOOL oldChanged = changed;
	changed = newChanged;
	
	if (oldChanged != newChanged) [self itemHasChanged];
}

// = Annotation =

- (NSString*) annotation {
	return annotation;
}

- (void) setAnnotation: (NSString*) newAnnotation {
	if (annotation == nil || ![newAnnotation isEqualToString: annotation]) 
		annotationSizeDidChange = YES;
	else
		return;					// Nothing to do
	if (annotation) [annotation release];
	annotation = nil;
	if (newAnnotation && ![newAnnotation isEqualToString: @""]) annotation = [newAnnotation copy];
	
	if (newAnnotation != nil && [newAnnotation length] > 0) {
		[self setBranchTemporary: NO];
	}
	
	[self itemHasChanged];
}

// = Commentary =

- (NSString*) commentary {
	return commentary;
}

- (void) setCommentary: (NSString*) newCommentary {
	if ([newCommentary isEqualToString: commentary]) return;				// Nothing to do
	
	[commentary release]; commentary = nil;
	commentary = [newCommentary copy];

	commentaryComparison = ZoomSkeinNotCompared;
	
	if (newCommentary != nil && [newCommentary length] > 0) {
		[self setBranchTemporary: NO];
	}

	[self itemHasChanged];
}

- (NSString*) stripWhitespace: (NSString*) otherString {
	NSMutableString* res = [[otherString mutableCopy] autorelease];
	
	int pos;
	for (pos=0; pos<[res length]; pos++) {
		unichar chr = [res characterAtIndex: pos];
		
		if (chr == '\n' || chr == '\r' || chr == ' ' || chr == '\t') {
			// Whitespace character
			[res deleteCharactersInRange: NSMakeRange(pos, 1)];
			pos--;
		}
	}
	
	// Remove a trailing '>'
	if ([res length] > 0 && [res characterAtIndex: [res length]-1] == '>') {
		[res deleteCharactersInRange: NSMakeRange([res length]-1, 1)];
	}
	
	return res;
}

- (ZoomSkeinComparison) forceCommentaryComparison {
    if (result == nil || [result length] == 0
        || commentary == nil || [commentary length] == 0) {
        // If either the result of commentary is of 0 length, then there is no result
        commentaryComparison = ZoomSkeinNoResult;
    } else {
        // Compare the two strings (taking account of whitespace)
        NSComparisonResult compareResult = [result compare: commentary];

        if (compareResult == NSOrderedSame) {
            // These two items are exactly the same
            commentaryComparison = ZoomSkeinIdentical;
        } else {
            // Compare the two strings (ignoring whitespace)
            compareResult = [[self stripWhitespace: result] compare: [self stripWhitespace: commentary]];

            if (compareResult == NSOrderedSame) {
                commentaryComparison = ZoomSkeinDiffersOnlyByWhitespace;
            } else {
                commentaryComparison = ZoomSkeinDifferent;
            }
        }
    }
    return commentaryComparison;
}


- (ZoomSkeinComparison) commentaryComparison {
	if (commentaryComparison == ZoomSkeinNotCompared) {
        [self forceCommentaryComparison];
	}
	
	return commentaryComparison;
}

- (ZoomSkeinItem*) nextDiffDown {
	// Finds the next difference (below this item)
	NSEnumerator* childEnum = [[self children] objectEnumerator];
	ZoomSkeinItem* child;
	
	while (child = [childEnum nextObject]) {
		int compare = [child commentaryComparison];
		if (compare == ZoomSkeinDifferent
			|| compare == ZoomSkeinDiffersOnlyByWhitespace) {
			return child;
		}
		
		ZoomSkeinItem* childDiff = [child nextDiffDown];
		if (childDiff != nil) return childDiff;
	}
	
	return nil;
}

- (ZoomSkeinItem*) nextDiff {
	// Finds the next difference (either below this item, or to the right in the skein)
	ZoomSkeinItem* diffBelow = [self nextDiffDown];
	if (diffBelow != nil) return diffBelow;
	
	// Iterate up from this point
	ZoomSkeinItem* top = self;
	ZoomSkeinItem* ourBranch;
	
	while (top != nil) {
		ourBranch = top;
		top = [top parent];
	
		while (top != nil && [[top children] count] <= 1) {
			ourBranch = top;
			top = [top parent];
		}
		
		// Find the item to the right
		NSEnumerator* childEnum = [[top children] objectEnumerator];
		ZoomSkeinItem* child;
		BOOL foundBranch = NO;
		
		while (child = [childEnum nextObject]) {
			if (child == ourBranch) {
				foundBranch = YES;
				break;
			}
		}	

		// See if we can find any differences there
		while (foundBranch && (child = [childEnum nextObject])) {
			diffBelow = [child nextDiffDown];
			if (diffBelow) return diffBelow;
		}
	}
	
	return nil;
}

// = Taking part in a set =

- (NSUInteger)hash {
	// Items are distinguished by their command
	return [command hash];
}

- (BOOL)isEqual:(id)anObject {
	if ([anObject isKindOfClass: [NSString class]]) {
		// We can be equal to a string with the same value as our command
		return [anObject isEqual: command];
	}
	
	// But we can't be equal to any other type of object, except ZoomSkeinItem
	if (![anObject isKindOfClass: [ZoomSkeinItem class]])
		return NO;
	
	// We compare on commands
	ZoomSkeinItem* otherItem = anObject;
	
	return [[otherItem command] isEqual: command];
}

// = NSCoding =

- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeObject: children
				   forKey: @"children"];
	
	[encoder encodeObject: command
				   forKey: @"command"];
	[encoder encodeObject: result
				   forKey: @"result"];
	[encoder encodeObject: annotation
				   forKey: @"annotation"];
	
	[encoder encodeBool: played
				 forKey: @"played"];
	[encoder encodeBool: changed
				 forKey: @"changed"];
	[encoder encodeBool: temporary
				 forKey: @"temporary"];
	[encoder encodeInt: tempScore
				forKey: @"tempScore"];
}

- (instancetype)initWithCoder: (NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		children = [[decoder decodeObjectForKey: @"children"] retain];
		
		command = [[decoder decodeObjectForKey: @"command"] retain];
		result = [[decoder decodeObjectForKey: @"result"] retain];
		annotation = [[decoder decodeObjectForKey: @"annotation"] retain];
		
		played = [decoder decodeBoolForKey: @"played"];
		changed = [decoder decodeBoolForKey: @"changed"];
		temporary = [decoder decodeBoolForKey: @"temporary"];
		tempScore = [decoder decodeIntForKey: @"tempScore"];
		
		NSEnumerator* childEnum = [children objectEnumerator];
		ZoomSkeinItem* child;
		while (child = [childEnum nextObject]) {
			child->parent = self;
		}

		annotationSizeDidChange = commandSizeDidChange = YES;
	}
	
	return self;
}

// = Drawing/sizing =

//
// These routines are implemented here for performance reasons
// sizeWithAttributes is *slow* under OS X, and calling it unnecessarily severely impacts the performance of
// Zoom
//

static NSDictionary* itemTextAttributes = nil;
static NSDictionary* labelTextAttributes = nil;

- (NSSize) commandSize {
	if (!itemTextAttributes) {
		itemTextAttributes = [@{NSFontAttributeName: [NSFont systemFontOfSize: 10],
			NSForegroundColorAttributeName: [NSColor blackColor]} retain];
	}
	
	if (commandSizeDidChange) {
		commandSize = [command sizeWithAttributes: itemTextAttributes];
	}
	
	commandSizeDidChange = NO;
	return commandSize;
}

- (void) drawCommandAtPosition: (NSPoint) position {
	[command drawAtPoint: position
		  withAttributes: itemTextAttributes];
}

- (NSSize) annotationSize {
	if (!labelTextAttributes) {
		labelTextAttributes = [@{NSFontAttributeName: [NSFont systemFontOfSize: 13],
			NSForegroundColorAttributeName: [NSColor blackColor]} retain];
	}
	
	if (annotationSizeDidChange) {
		annotationSize = annotation?[annotation sizeWithAttributes: labelTextAttributes]:NSMakeSize(0,0);
	}
	
	annotationSizeDidChange = NO;
	return annotationSize;
}

- (void) drawAnnotationAtPosition: (NSPoint) position {
	if (annotation) {
		[annotation drawAtPoint: position
				 withAttributes: labelTextAttributes];
	}
}

@end
