//
//  ZoomSkeinItem.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomSkeinItem.h"
#import "ZoomSkeinInternal.h"

// Skein item notifications
NSString*const ZoomSkeinItemIsBeingReplaced = @"ZoomSkeinItemIsBeingReplaced";
NSString*const ZoomSkeinItemHasBeenRemovedFromTree = @"ZoomSkeinItemHasBeenRemovedFromTree";
NSString*const ZoomSkeinItemHasChanged = @"ZoomSkeinItemHasChanged";
NSString*const ZoomSkeinItemHasNewChild = @"ZoomSkeinItemHasNewChild";

// Skein item notification dictionary keys
NSString*const ZoomSIItem = @"ZoomSIItem";
NSString*const ZoomSIOldItem = @"ZoomSIOldItem";
NSString*const ZoomSIOldParent = @"ZoomSIOldParent";
NSString*const ZoomSIChild = @"ZoomSIChild";

@interface ZoomSkeinItem ()
@property (readwrite, weak) ZoomSkeinItem* parent;
@end

@implementation ZoomSkeinItem {
	NSMutableSet<ZoomSkeinItem*>* children;
	
	// Cached layout items (text measuring is slow)
	BOOL   commandSizeDidChange;
	NSSize commandSize;
	
	BOOL   annotationSizeDidChange;
	NSSize annotationSize;
}

#pragma mark - Initialisation

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
		command = [[NSString alloc] initWithCharactersNoCopy: uniBuf
													  length: [command length] - spaces
												freeWhenDone: YES];
	} else {
		free(uniBuf);
	}
	
	return command;
}

+ (ZoomSkeinItem*) skeinItemWithCommand: (NSString*) com {
	return [[[self class] alloc] initWithCommand: com];
}

- (instancetype) initWithCommand: (nullable NSString*) com identifier: (NSUUID*) uuid {
	self = [super init];
	
	if (self) {
		command = [convertCommand(com) copy];
		result  = nil;
		
		parent = nil;
		_nodeIdentifier = uuid;
		children = [[NSMutableSet alloc] init];
		
		temporary = YES;
		tempScore = 0;
		played    = NO;
		changed   = YES;
		
		annotation = nil;
		
		annotationSizeDidChange = commandSizeDidChange = YES;
	}
	
	return self;
}

- (id) initWithCommand: (NSString*) com {
	return [self initWithCommand: com identifier: [NSUUID UUID]];
}

- (id) init {
	return [self initWithCommand: nil identifier: [NSUUID UUID]];
}

- (void) dealloc {
	// First, mark the old items as having no parent
	NSMutableArray* childrenToDestroy = [NSMutableArray array];
	NSEnumerator* objEnum = [children objectEnumerator];
	ZoomSkeinItem* child;
	for (child in objEnum) {
		[childrenToDestroy addObject: child];
	}
	
	// Luke, I am your father
	[childrenToDestroy makeObjectsPerformSelector: @selector(removeFromParent)];
	
	// NOOOOOOO
	//[super dealloc];
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

#pragma mark - Skein tree
@synthesize parent;

- (NSSet*) children {
	return [children copy];
}

- (ZoomSkeinItem*) childWithCommand: (NSString*) com {
	for (ZoomSkeinItem* skeinItem in children) {
		if ([[skeinItem command] isEqualToString: com]) {
			return skeinItem;
		}
	}
	
	return nil;
}

- (void) mergeWith: (ZoomSkeinItem*) newItem {
	// Merges this item with another
	for (ZoomSkeinItem* childItem in [newItem children]) {
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
		
		if (!childItem.temporary) [oldChild setTemporary: NO];
		[oldChild setPlayed: [childItem played]];
		[oldChild setChanged: [childItem changed]];
		
		// 'New' item is the old one
		[childItem itemIsBeingReplacedBy: oldChild];
		
		return oldChild;
	} else {
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
	
	for (ZoomSkeinItem* child in children) {
		if ([child hasChild: item]) return YES;
	}
	
	return NO;
}

- (BOOL) hasChildWithCommand: (NSString*) theCommand {
	if (theCommand == nil) theCommand = @"";
	
	for (ZoomSkeinItem* child in children) {
		NSString* childCommand = [child command];
		if (childCommand == nil) childCommand = @"";
		
		if ([childCommand isEqualToString: theCommand]) return YES;
	}
	
	return NO;
}

#pragma mark - Item data

@synthesize command;
@synthesize result;

- (void) setCommand: (NSString*) newCommand {
	if ([newCommand isEqualToString: command]) return;			// Nothing to do
	
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
	
	result = [newResult copy];
	
	commentaryComparison = ZoomSkeinNotCompared;
	
	[self itemHasChanged];
}

#pragma mark - Item state

@synthesize temporary;
@synthesize temporaryScore = tempScore;
@synthesize played;
@synthesize changed;

- (void) setTemporary: (BOOL) isTemporary {
	temporary = isTemporary;
	
	ZoomSkeinItem* p = [self parent];
	
	// Also applies to parent items if set to 'NO'
	if (!isTemporary) {
		while (p != nil && [p parent] != nil) {
			if (!p.temporary) break;
			[p setTemporary: NO];
			
			p = [p parent];
		}
	} else {
		// Applies to child items if set to 'YES'
		for (ZoomSkeinItem* child in [self children]) {
			if (!child.temporary) [child setTemporary: YES];
		}
	}
	
	[self itemHasChanged];
}

- (void) setBranchTemporary: (BOOL) isTemporary {
	ZoomSkeinItem* lowerItem = self;
	if (!isTemporary) {
		// Find the lowermost item in this branch (ie, set this entire branch as temporary)		
		while ([[lowerItem children] count] == 1) {
			lowerItem = [[[lowerItem children] allObjects] objectAtIndex: 0];
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

#pragma mark - Annotation

@synthesize annotation;

- (void) setAnnotation: (NSString*) newAnnotation {
	if (annotation == nil || ![newAnnotation isEqualToString: annotation]) 
		annotationSizeDidChange = YES;
	else
		return;					// Nothing to do
	annotation = nil;
	if (newAnnotation && ![newAnnotation isEqualToString: @""]) annotation = [newAnnotation copy];
	
	if (newAnnotation != nil && [newAnnotation length] > 0) {
		[self setBranchTemporary: NO];
	}
	
	[self itemHasChanged];
}

#pragma mark - Commentary

@synthesize commentary;

- (void) setCommentary: (NSString*) newCommentary {
	if ([newCommentary isEqualToString: commentary]) return;				// Nothing to do
	
	commentary = [newCommentary copy];

	commentaryComparison = ZoomSkeinNotCompared;
	
	if (newCommentary != nil && [newCommentary length] > 0) {
		[self setBranchTemporary: NO];
	}

	[self itemHasChanged];
}

- (NSString*) stripWhitespace: (NSString*) otherString {
	NSMutableString* res = [otherString mutableCopy];
	
	// Sigh. Need perl. (stringByTrimmingCharactersInSet would have been perfect if it applied across the whole string)
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

@synthesize commentaryComparison;
- (ZoomSkeinComparison) commentaryComparison {
	if (commentaryComparison == ZoomSkeinNotCompared) {
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
	}
	
	return commentaryComparison;
}

- (ZoomSkeinItem*) nextDiffDown {
	// Finds the next difference (below this item)
	NSEnumerator* childEnum = [[self children] objectEnumerator];
	
	for (ZoomSkeinItem* child in childEnum) {
		ZoomSkeinComparison compare = [child commentaryComparison];
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

#pragma mark - Taking part in a set

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

#pragma mark - NSCoding

- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeObject: children
				   forKey: @"children"];
	
	[encoder encodeObject: command
				   forKey: @"command"];
	[encoder encodeObject: result
				   forKey: @"result"];
	[encoder encodeObject: annotation
				   forKey: @"annotation"];
	[encoder encodeObject: _nodeIdentifier
				   forKey: @"nodeUUID"];
	
	[encoder encodeBool: played
				 forKey: @"played"];
	[encoder encodeBool: changed
				 forKey: @"changed"];
	[encoder encodeBool: temporary
				 forKey: @"temporary"];
	[encoder encodeInt: tempScore
				forKey: @"tempScore"];
}

- (id)initWithCoder: (NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		children = [decoder decodeObjectOfClasses: [NSSet setWithObjects: [NSMutableSet class], [ZoomSkeinItem class], nil] forKey: @"children"];
		
		command = [decoder decodeObjectOfClass: [NSString class] forKey: @"command"];
		result = [decoder decodeObjectOfClass: [NSString class] forKey: @"result"];
		annotation = [decoder decodeObjectOfClass: [NSString class] forKey: @"annotation"];
		_nodeIdentifier = [decoder decodeObjectOfClass: [NSUUID class] forKey: @"nodeUUID"];
		if (!_nodeIdentifier) {
			// UUID decoder failure means old-style, pointer-derived xml.
			_nodeIdentifier = [NSUUID UUID];
		}
		
		played = [decoder decodeBoolForKey: @"played"];
		changed = [decoder decodeBoolForKey: @"changed"];
		temporary = [decoder decodeBoolForKey: @"temporary"];
		tempScore = [decoder decodeIntForKey: @"tempScore"];
		
		NSEnumerator* childEnum = [children objectEnumerator];
		for (ZoomSkeinItem* child in childEnum) {
			child->parent = self;
		}

		annotationSizeDidChange = commandSizeDidChange = YES;
	}
	
	return self;
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

#pragma mark - Drawing/sizing

//
// These routines are implemented here for performance reasons
// sizeWithAttributes is *slow* under OS X, and calling it unnecessarily severely impacts the performance of
// Zoom
//

- (NSSize) commandSize {
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
