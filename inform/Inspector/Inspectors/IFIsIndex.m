//
//  IFIsIndex.m
//  Inform
//
//  Created by Andrew Hunter on Fri May 07 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIsIndex.h"
#import "IFAppDelegate.h"

#import "IFPreferences.h"

#import "IFIndexFile.h"
#import "IFProjectController.h"
#import "IFProject.h"
#import "IFProjectPane.h"
#import "IFUtility.h"
#import "NSBundle+IFBundleExtensions.h"

NSString* IFIsIndexInspector = @"IFIsIndexInspector";

@implementation IFIsIndex

+ (IFIsIndex*) sharedIFIsIndex {
	static IFIsIndex* sharedIndex = nil;
	
	if (sharedIndex == nil && [IFAppDelegate isWebKitAvailable]) {
		sharedIndex = [[IFIsIndex alloc] init];
	}
	
	return sharedIndex;
}

- (id) init {
	self = [super init];
	
	if (self) {
		[self setTitle: [IFUtility localizedString: @"Inspector Index"
                                           default: @"Index"]];
		[NSBundle oldLoadNibNamed: @"IndexInspector"
                            owner: self];
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(intelFileChanged:)
													 name: IFIntelFileHasChangedNotification
												   object: nil];
	}

	return self;
}

- (void) dealloc {
	[super dealloc];
}

- (NSString*) key {
	return IFIsIndexInspector;
}

- (BOOL) available {
	return canDisplay;
}

- (void) inspectWindow: (NSWindow*) window {
	activeWindow = window;
	
	canDisplay = NO;
	if ([window windowController] != nil) {
		[self updateIndexFrom: [window windowController]];
	}
}

- (void) updateIndexFrom: (NSWindowController*) window {
	if ([window window] != activeWindow) return;
	
	if ([window isKindOfClass: [IFProjectController class]]) {
		canDisplay = YES;
	
		[indexList setDataSource: self];
		[indexList reloadData];
	}
}

// = NSOutlineView delegate methods =

- (void) cacheSiblingsOf: (IFIntelSymbol*) symbol 
				 inCache: (NSMutableArray*) cache {
	// Static data (saves some space)
	static NSArray* noChildren = nil;
	if (!noChildren) noChildren = [[NSArray array] retain];
	
	// We store things in symbol, children order
 	IFIntelSymbol* currentSymbol = symbol;
	
	do {
		IFIntelSymbol* child = [currentSymbol child];
		IFIntelSymbol* sibling = [currentSymbol sibling];
		
		if (child) {
			NSMutableArray* childrenArray = [NSMutableArray array];
			
			[self cacheSiblingsOf: child
						  inCache: childrenArray];
			
			[cache addObject: [NSArray arrayWithObjects: currentSymbol, childrenArray, nil]];
		} else {
			[cache addObject: [NSArray arrayWithObjects: currentSymbol, noChildren, nil]];
		}
		
		currentSymbol = sibling;
	} while (currentSymbol);
}

- (void) cacheItems {
	// Cache the outline tree as it currently is
	if (itemCache) return;
	
	// The item cache exists to make sure all the items that we might display are retained, as they might
	// otherwise disappear
	itemCache = [[NSMutableArray alloc] init];
	IFProjectController* proj = [activeWindow windowController];

	if (![proj isKindOfClass: [IFProjectController class]]) return;
	if ([[proj currentIntelligence] firstSymbol] == nil) return;
	
	[self cacheSiblingsOf: [[proj currentIntelligence] firstSymbol]
				  inCache: itemCache];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	[self cacheItems];
	
	if (canDisplay) {
		IFProjectController* proj = [activeWindow windowController];
		
		int selectedRow = [indexList selectedRow];
		if (selectedRow < 0) return; // Nothing to do

		id selectedItem = [indexList itemAtRow: selectedRow];
		if ([selectedItem isKindOfClass: [NSArray class]] && [selectedItem count] == 2) selectedItem = [selectedItem objectAtIndex: 0];
		
		if ([selectedItem isKindOfClass: [IFIntelSymbol class]]) {
			int lineNumber = [[proj currentIntelligence] lineForSymbol: selectedItem]+1;

			if (lineNumber != NSNotFound) {
				[proj removeAllTemporaryHighlights];
				[proj highlightSourceFileLine: lineNumber
									   inFile: [[[proj sourcePane] sourcePage] currentFile]
										style: IFLineStyleHighlight];
				[proj moveToSourceFileLine: lineNumber];
			}
		} else {
			IFIndexFile* index = [[proj document] indexFile];
		
			NSString* filename = [index filenameForItem: selectedItem];
			int line = [index lineForItem: selectedItem];
		
			if (filename != nil &&
				[proj selectSourceFile: filename]) {
				if (line >= 0) {
					[proj removeAllTemporaryHighlights];
					[proj highlightSourceFileLine: line
										   inFile: filename
											style: IFLineStyleHighlight];
					[proj moveToSourceFileLine: line];
				}
			} else {
				NSLog(@"IFIsIndex: Can't select file '%@' (line '%d)", filename, line);
			}
		}
	}
}

// = NSOutlineView data source =

// This will display the real-time data instead of the indexfile data

- (id)outlineView: (NSOutlineView *)outlineView 
			child: (int)childIndex 
		   ofItem: (id)item {
	[self cacheItems];
	
	if (item == nil) {
		return [itemCache objectAtIndex: childIndex];
	} else if ([item isKindOfClass: [NSArray class]] && [item count] == 2) {
		return [[item objectAtIndex: 1] objectAtIndex: childIndex];
	} else {
		return @"<< BAD CHILD (no cookie!) >>";
	}
}

- (BOOL)outlineView: (NSOutlineView *)outlineView
   isItemExpandable: (id)item {
	[self cacheItems];
	
	if ([item isKindOfClass: [NSArray class]] && [item count] == 2) {
		return [[item objectAtIndex: 1] count] > 0;
	} else {
		return NO;
	}
}

- (int)			outlineView:(NSOutlineView *)outlineView 
	 numberOfChildrenOfItem:(id)item {
	[self cacheItems];
	
	if (item == nil) {
		return [itemCache count];
	} else if ([item isKindOfClass: [NSArray class]] && [item count] == 2) {
		return [[item objectAtIndex: 1] count];
	} else {
		return 0;
	}	
}

- (id)				outlineView:(NSOutlineView *)outlineView 
	  objectValueForTableColumn:(NSTableColumn *)tableColumn
						 byItem:(id)item {
	[self cacheItems];
	
	if ([item isKindOfClass: [NSString class]]) return item;

	// Valid column identifiers are 'title' and 'line'
	NSString* identifier = [tableColumn identifier];
	
	if (item == nil) {
		// Root item
		return nil;
	}
	
	if ([item isKindOfClass: [NSArray class]] && [item count] == 2) {
		if ([identifier isEqualToString: @"title"]) {
			return [[item objectAtIndex: 0] name];
		} else if ([identifier isEqualToString: @"line"]) {
			IFProjectController* proj = [activeWindow windowController];
			IFIntelFile* intel = [proj currentIntelligence];
			
			int line = [intel lineForSymbol: [item objectAtIndex: 0]];
			
			return [NSString stringWithFormat: @"%i", line];
		} else {
			return @"--";
		}
	}
	
	// Bug if we reach this position.
	return @"<< BAD ITEM >>";
}

- (void) intelFileChanged: (NSNotification*) not {
	[itemCache release]; 
	itemCache = nil;
	
	[self cacheItems];
	
	[indexList reloadData];
}

@end
