//
//  ZoomSkein.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#define maxTempItems 30

#import "ZoomSkein.h"

@interface ZoomSkeinInputSource : NSObject {
	NSMutableArray* commandStack;
}

- (void) setCommandStack: (NSMutableArray*) stack;
- (NSString*) nextCommand;

@end

@implementation ZoomSkein

- (id) init {
	self = [super init];
	
	if (self) {
		rootItem = [[ZoomSkeinItem alloc] initWithCommand: @"- start -"];		
		activeItem = [rootItem retain];
		currentOutput = [[NSMutableString alloc] init];
		
		[rootItem setTemporary: NO];
		[rootItem setPlayed: YES];
		
		webData = nil;
	}
	
	return self;
}

- (void) dealloc {
	[activeItem release];
	[rootItem release];
	[currentOutput release];
	
	if (webData) [webData release];
	
	[super dealloc];
}

- (ZoomSkeinItem*) rootItem {
	return rootItem;
}

- (ZoomSkeinItem*) activeItem {
	return activeItem;
}

- (void) setActiveItem: (ZoomSkeinItem*) active {
	[activeItem release];
	activeItem = [active retain];
}

// = Notifications =

NSString* ZoomSkeinChangedNotification = @"ZoomSkeinChangedNotification";

- (void) zoomSkeinChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomSkeinChangedNotification
														object: self];
}

// = Zoom output receiver =

- (void) inputCommand: (NSString*) command {
	// Create/set the item to the appropraite item in the skein
	ZoomSkeinItem* newItem = [activeItem addChild: [ZoomSkeinItem skeinItemWithCommand: command]];
	
	// Move the 'active' item
	[activeItem release];
	activeItem = [newItem retain];
	
	// Some values for this item
	[activeItem setPlayed: YES];
	[activeItem increaseTemporaryScore];
	
	// Create a buffer for any new output
	if (currentOutput) [currentOutput release];
	currentOutput = [[NSMutableString alloc] init];
	
	// Notify anyone who's watching that we've updated
	[self zoomSkeinChanged];
}

- (void) inputCharacter: (NSString*) character {
	// We convert characters to their ZSCII equivalent (codes 129-144 and 252-254 for mouse clicks)
	unichar key;
	
	key = 0;
	switch ([character characterAtIndex: 0]) {
		// Arrow keys
		case NSUpArrowFunctionKey: key = 129; break;
		case NSDownArrowFunctionKey: key = 130; break;
		case NSLeftArrowFunctionKey: key = 131; break;
		case NSRightArrowFunctionKey: key = 132; break;
			
			// Delete/return
		case NSDeleteFunctionKey: key = 8; break;
			
			// Function keys
		case NSF1FunctionKey: key = 133; break;
		case NSF2FunctionKey: key = 134; break;
		case NSF3FunctionKey: key = 135; break;
		case NSF4FunctionKey: key = 136; break;
		case NSF5FunctionKey: key = 137; break;
		case NSF6FunctionKey: key = 138; break;
		case NSF7FunctionKey: key = 139; break;
		case NSF8FunctionKey: key = 140; break;
		case NSF9FunctionKey: key = 141; break;
		case NSF10FunctionKey: key = 142; break;
		case NSF11FunctionKey: key = 143; break;
		case NSF12FunctionKey: key = 144; break;
			
			// Mouse buttons (we use fake function keys for this)
		case NSF33FunctionKey: key = 252; break;
		case NSF34FunctionKey: key = 254; break;
		case NSF35FunctionKey: key = 253; break;
	}
	
	if (key != 0) {
		NSMutableString* newCharacter = [character mutableCopy];
		
		[newCharacter replaceCharactersInRange: NSMakeRange(0,1)
									withString: [NSString stringWithCharacters: &key
																		length: 1]];
		
		character = [newCharacter autorelease];
	}
	
	
	[self inputCommand: character];
}

- (void) outputText: (NSString*) outputText {
	// Append this text to the current outout
	[currentOutput appendString: outputText];

	//if ([currentOutput length] > 0) {
	//	[activeItem setResult: currentOutput];
	//}
}

- (void) zoomWaitingForInput {
	// Send the current output to the active item
	if ([currentOutput length] > 0) {
		[activeItem setResult: currentOutput];

		[currentOutput release];
		currentOutput = [[NSMutableString alloc] init];
	}
}

- (void) zoomInterpreterRestart {
	[self zoomWaitingForInput];
	
	// Back to the top
	[activeItem release];
	activeItem = [rootItem retain];
	
	[self zoomSkeinChanged];
	
	[self removeTemporaryItems: maxTempItems];
}

// = Creating a Zoom input receiver =

+ (id) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
						 toItem: (ZoomSkeinItem*) item2 {
	// item1 must be a parent of item2, and neither can be nil
	
	// item1 is not executed
	if (item1 == nil || item2 == nil) return nil;
	
	NSMutableArray* commandsToExecute = [NSMutableArray array];
	ZoomSkeinItem* parent = item2;
	
	while (parent != item1) {
		NSString* cmd = [parent command];
		if (cmd == nil) cmd = @"";
		[commandsToExecute addObject: cmd];
		
		parent = [parent parent];
		if (parent == nil) return nil;
	}
	
	// commandsToExecute contains the list of commands we need to execute
	ZoomSkeinInputSource* source = [[ZoomSkeinInputSource alloc] init];
	
	[source setCommandStack: commandsToExecute];
	return [source autorelease];
}

- (id) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
						 toItem: (ZoomSkeinItem*) item2 {
	return [[self class] inputSourceFromSkeinItem: item1
										   toItem: item2];
}

// = Removing temporary items =

- (void) removeTemporaryItems: (int) maxTemps {
	//
	// Maybe a bit confusing: the temporary counter is updated in various ways, but
	// more recent items are always given a higher number. 'maxTemps' is really
	// an indication in the maximum breadth of the tree.
	//
	
	NSMutableSet* itemsInUse = [NSMutableSet set];
	
	// (I have no faith in Apple's ulimits)
	NSMutableArray* itemStack = [NSMutableArray array];
	
	[itemStack addObject: rootItem];
	
	while ([itemStack count] > 0) {
		// Pop the latest item from the stack
		ZoomSkeinItem* item = [itemStack lastObject];
		[itemStack removeLastObject];
		
		// Add this item to the list of items in use
		if ([item temporary]) {
			[itemsInUse addObject: [NSNumber numberWithInt: [item temporaryScore]]];
		}
		
		// Push this item's children onto the stack
		NSEnumerator* childEnum = [[item children] objectEnumerator];
		ZoomSkeinItem* child;
		while (child = [childEnum nextObject]) {
			[itemStack addObject: child];
		}
	}
	
	// Keep only the highest maxTemps scores (and those that are not marked as temporary, of course)
	NSArray* itemList = [[itemsInUse allObjects] sortedArrayUsingSelector: @selector(compare:)];
	if ([itemList count] <= maxTemps) return;
	
	itemList = [itemList subarrayWithRange: NSMakeRange(0, [itemList count] - maxTemps)];
	
	NSSet* itemsToRemove = [NSSet setWithArray: itemList];
	
	[itemStack addObject: rootItem];
	
	while ([itemStack count] > 0) {
		// Pop the latest item from the stack
		ZoomSkeinItem* item = [[itemStack lastObject] retain];
		[itemStack removeLastObject];

		// Remove this item if necessary
		if ([item temporary] && [itemsToRemove containsObject: [NSNumber numberWithInt: [item temporaryScore]]]) {
			[item removeFromParent];
		} else {
			// Push this item's children onto the stack
			NSEnumerator* childEnum = [[item children] objectEnumerator];
			ZoomSkeinItem* child;
			while (child = [childEnum nextObject]) {
				[itemStack addObject: child];
			}
		}
        [item release];
	}
}


// = Annotation lists =

static NSComparisonResult stringCompare(id a, id b, void* context) {
	return [(NSString*)a compare: b];
}

- (NSArray*) annotations {
	if (rootItem == nil) return nil;
	
	// The result
	NSMutableSet* resSet = [NSMutableSet set];
	
	// Iterate through the items
	NSMutableArray* stack = [NSMutableArray array];
	[stack addObject: rootItem];
	
	while ([stack count] > 0) {
		ZoomSkeinItem* item = [stack lastObject];
		[stack removeLastObject];
		
		if ([[item annotation] length] > 0) {
			[resSet addObject: [item annotation]];
		}
		
		[stack addObjectsFromArray: [[item children] allObjects]];
	}
	
	// Return the result
	return [[resSet allObjects] sortedArrayUsingFunction: stringCompare
												 context: nil];
}

- (NSMenu*) populateMenuWithAction: (SEL) action
							target: (id) target {
	NSMenu* result = [[[NSMenu alloc] init] autorelease];
	
	NSArray* items = [self annotations];
	NSEnumerator* itemEnum = [items objectEnumerator];
	NSString* item;
	
	while (item = [itemEnum nextObject]) {
		NSMenuItem* newItem = [[NSMenuItem alloc] initWithTitle: item
														 action: action
												  keyEquivalent: @""];
		[newItem setTarget: target];
		
		[result addItem: newItem];
		[newItem release];
	}
	
	return result;
}

- (void) populatePopupButton: (NSPopUpButton*) button {
	[button removeAllItems];
	
	// Get the list of annotations
	NSArray* items = [self annotations];
	
	[button addItemWithTitle: [[NSBundle mainBundle] localizedStringForKey: @"Go to label..."
																	 value: @"Go to label..."
																	 table: nil]];
	[button addItemsWithTitles: items];
}

- (NSArray*) itemsWithAnnotation: (NSString*) annotation {
	if (rootItem == nil) return nil;
	
	// The result
	NSMutableArray* res = [NSMutableArray array];
	
	// Iterate through the items
	NSMutableArray* stack = [NSMutableArray array];
	[stack addObject: rootItem];
	
	while ([stack count] > 0) {
		ZoomSkeinItem* item = [stack lastObject];
		[stack removeLastObject];
		
		if ([annotation isEqualToString: [item annotation]]) {
			[res addObject: item];
		}
		
		[stack addObjectsFromArray: [[item children] allObjects]];
	}
	
	// Return the result
	return res;
}

// = Converting to other formats =

- (NSString*) transcriptToPoint: (ZoomSkeinItem*) item {
	if (item == nil) item = activeItem;
	
	// Get the list of items
	NSMutableArray* itemList = [NSMutableArray array];
	while (item != nil) {
		[itemList addObject: item];
		
		item = [item parent];
	}
	
	NSMutableString* result = [[NSMutableString alloc] init];
	while ([itemList count] > 0) {
		// Retrieve the next item
		ZoomSkeinItem* thisItem = [itemList lastObject];
		[itemList removeLastObject];
		
		// Add it to the transcript
		if (thisItem != rootItem) {
			[result appendString: [thisItem command]];
			[result appendString: @"\n"];
		}
		if ([thisItem result] != nil) {
			[result appendString: [thisItem result]];
		}
	}
	
	return [result autorelease];
}

- (NSString*) recordingToPoint: (ZoomSkeinItem*) item {
	if (item == nil) item = activeItem;
	
	// Get the list of items
	NSMutableArray* itemList = [NSMutableArray array];
	while (item != nil) {
		[itemList addObject: item];
		
		item = [item parent];
	}
	
	NSMutableString* result = [[NSMutableString alloc] init];
	while ([itemList count] > 0) {
		// Retrieve the next item
		ZoomSkeinItem* thisItem = [itemList lastObject];
		[itemList removeLastObject];
		
		// Add it to the transcript
		if (thisItem != rootItem) {
			[result appendString: [thisItem command]];
			[result appendString: @"\n"];
		}
	}
	
	return [result autorelease];
}

@end

// = Our input source object =

@implementation ZoomSkeinInputSource

- (id) init {
	self = [super init];
	
	if (self) {
		commandStack = nil;
	}
	
	return self;
}

- (void) dealloc {
	[commandStack release];
	[super dealloc];
}

- (void) setCommandStack: (NSMutableArray*) stack {
	[commandStack release];
	commandStack = [stack retain];
}

- (NSString*) nextCommand {
	if ([commandStack count] <= 0) return nil;
	
	NSString* nextCommand = [[commandStack lastObject] retain];
	[commandStack removeLastObject];
	return [nextCommand autorelease];
}

- (BOOL) disableMorePrompt {
	return YES;
}

@end

