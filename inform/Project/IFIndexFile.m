//
//  IFIndexFile.m
//  Inform
//
//  Created by Andrew Hunter on Sun Jun 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIndexFile.h"


@implementation IFIndexFile

- (id) initWithContentsOfFile: (NSString*) filename {
	self = [self initWithData: [NSData dataWithContentsOfFile: filename]];
	
	return self;
}

static NSInteger intValueComparer(id a, id b, void* context) {
	int aV = [a intValue];
	int bV = [b intValue];
	
	if (aV < bV) return -1;
	if (aV > bV) return 1;
	return 0;
}

- (id) initWithData: (NSData*) data {
	self = [super init];
	
	if (self) {
		if (data == nil) {
			[self release];
			return nil;
		}
		
		// Data is provided as a property list file, which makes things easy for us to parse
		// Req 10.2 (surely no-one is still seriously using 10.1?)
		NSPropertyListFormat format;
		NSString* error = nil;
		
		id plist =  [NSPropertyListSerialization propertyListFromData: data
													 mutabilityOption: NSPropertyListImmutable
															   format: &format
													 errorDescription: &error];
		
		// Sanity check
		if (plist == nil) {
			NSLog(@"IFIndexFile: found no data");
			[self release];
			return nil;
		}
		
		if (error != nil) {
			NSLog(@"IFIndexFile: error in file: %@", error);
			[self release];
			return nil;
		}
		
		if (![plist isKindOfClass: [NSDictionary class]]) {
			NSLog(@"IFIndexFile: property list does not contain a dictionary");
			[self release];
			return nil;
		}
		
		// OK: we've got an index in plist. Do some processing...
		index = [plist copy];
		
		// Need the keys sorted by numeric value to make any sense of them
		NSArray* orderedKeys = [index allKeys];
		orderedKeys = [orderedKeys sortedArrayUsingFunction: intValueComparer
													context: nil];
		
		// Turn the index into a hierarchical dictionary
		// Top level indexed by filenames
		filenamesToIndexes = [[NSMutableDictionary alloc] init];
		
		for( NSString* key in orderedKeys ) {
			NSDictionary* item = [index objectForKey: key];
			
			if ([item isKindOfClass: [NSDictionary class]] &&
				[item objectForKey: @"Filename"] != nil &&
				[item objectForKey: @"Indentation"] != nil &&
				[item objectForKey: @"Level"] != nil &&
				[item objectForKey: @"Line"] != nil &&
				[item objectForKey: @"Title"] != nil) {
				NSString* filename = [item objectForKey: @"Filename"];
				int indent = [[item objectForKey: @"Indentation"] intValue];
				int line   = [[item objectForKey: @"Line"] intValue];
				NSString* title = [item objectForKey: @"Title"];
				
				// HACK: only include the source files
				if (![[filename stringByDeletingLastPathComponent] isEqualToString: @"Source"]) continue;
				
				// Get the initial index for this file
				NSMutableArray* indexForFilename = [filenamesToIndexes objectForKey: filename];
				if (indexForFilename == nil) {
					indexForFilename = [[NSMutableArray alloc] init];
					[filenamesToIndexes setObject: [indexForFilename autorelease]
										   forKey: filename];
				} // indexForFilename == nil
				
				if ([title isEqualToString: @"--"]) continue; // Ignore these items
				
				// Each index level is an array of entries at a specific indentation level
				// Each item is a dictionary consisting of the 'Line' and 'Title' keys
				// plus a 'Contents' key which (if present) indicates the items that come
				// under this one.
				//
				// Items are assumed to appear in order, and the hierarchy is assumed not to cross
				// files
				NSMutableDictionary* newItem = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					title, @"Title", [NSNumber numberWithInt: line], @"Line", 
					filename, @"Filename", nil];
				
				// Iterate down to the lowest item
				NSMutableArray* indexToAdd = indexForFilename;
				int x;
				for (x=0; x<indent; x++) {
					NSMutableArray* newIndex = [[indexToAdd lastObject] objectForKey: @"Contents"];
					if (newIndex == nil) {
						if ([indexToAdd lastObject] == nil) {
							NSLog(@"IFIndexFile BUG: found an empty index");
							break;
						}
						
						// Need to add a new level
						newIndex = [[NSMutableArray alloc] init];
						[[indexToAdd lastObject] setObject: [newIndex autorelease]
													forKey: @"Contents"];
						indexToAdd = newIndex;
						break;
					}
					indexToAdd = newIndex;
				} // x=0;x<indent;x++
				
				// indexToAdd now contains the index where we need to add a new item - so do so
				[indexToAdd addObject: newItem];
			} // if (item is an index entry)
		} // key = [keyEnum nextObject]
		
		// Set up the rest of the data
	}
	
	return self;
}

- (void) dealloc {
	if (index) [index release];
	if (filenamesToIndexes) [filenamesToIndexes release];
	
	[super dealloc];
}

// == We can be an NSOutlineView data source ==

- (id)outlineView: (NSOutlineView *)outlineView 
			child: (int)childIndex 
		   ofItem: (id)item {
	if (item == nil) {
		// Root item
		NSArray* allKeys = [filenamesToIndexes allKeys];
		
		if (childIndex >= [allKeys count]) return nil;
		
		return [allKeys objectAtIndex: childIndex];
	} else if ([item isKindOfClass: [NSString class]]) {
		// Happens with the filename indexes only...
		NSArray* filenameIndex = [filenamesToIndexes objectForKey: item];
		
		if (childIndex >= [filenameIndex count]) return nil;
		
		return [filenameIndex objectAtIndex: childIndex];
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		NSMutableArray* contents = [itemDictionary objectForKey: @"Contents"];
		
		if (childIndex >= [contents count]) return nil;
		
		return [contents objectAtIndex: childIndex];
	}
}

- (BOOL)outlineView: (NSOutlineView *)outlineView
   isItemExpandable: (id)item {
	if (item == nil) {
		// Root item
		return YES;
	} else if ([item isKindOfClass: [NSString class]]) {
		// Happens with the filename indexes only...
		NSArray* filenameIndex = [filenamesToIndexes objectForKey: item];

		if ([filenameIndex count] <= 0)
			return NO;
		else
			return YES;
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		NSMutableArray* contents = [itemDictionary objectForKey: @"Contents"];
		
		if (contents == nil || [contents count] <= 0) 
			return NO;
		else
			return YES;
	}
}

- (int)			outlineView:(NSOutlineView *)outlineView 
	 numberOfChildrenOfItem:(id)item {
	if (item == nil) {
		// Root item
		NSArray* allKeys = [filenamesToIndexes allKeys];
		
		return [allKeys count];
	} else if ([item isKindOfClass: [NSString class]]) {
		// Happens with the filename indexes only...
		NSArray* filenameIndex = [filenamesToIndexes objectForKey: item];
		
		return [filenameIndex count];
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		NSMutableArray* contents = [itemDictionary objectForKey: @"Contents"];
		
		if (contents == nil || [contents count] <= 0) 
			return 0;
		else
			return [contents count];
	}
}

- (id)				outlineView:(NSOutlineView *)outlineView 
	  objectValueForTableColumn:(NSTableColumn *)tableColumn
						 byItem:(id)item {
	// Valid column identifiers are 'title' and 'line'
	NSString* identifier = [tableColumn identifier];
	
	if (item == nil) {
		// Root item
		return nil;
	} else if ([item isKindOfClass: [NSString class]]) {
		if ([identifier isEqualToString: @"title"]) {
			return item;
		} else if ([identifier isEqualToString: @"line"]) {
			return @"";
		} else {
			return nil;
		}
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		
		if ([identifier isEqualToString: @"title"]) {
			return [itemDictionary objectForKey: @"Title"];
		} else if ([identifier isEqualToString: @"line"]) {
			return [itemDictionary objectForKey: @"Line"];
		} else {
			return nil;
		}
	}
}

// == Functions for modifying what we display ==

// (None implemented yet)
// Possible ideas:
//   Search for symbols with specific names
//   Limit to only files in a particular set/IFProject object (ie avoid extensions file)

// == Functions ==

- (NSDictionary*) itemForItem: (id) item {
	// Given an item in the outline view, returns the item info NSDictionary
	if (item == nil) {
		// Root item has no dictionary
		return nil;
	} else if ([item isKindOfClass: [NSString class]]) {
		// Filename items are strings
		return [NSDictionary dictionaryWithObjectsAndKeys:
			item, @"Filename", item, @"Title", nil]; // Note: no line numbers
	} else if ([item isKindOfClass: [NSDictionary class]]) {
		// 'Normal' items are NSDictionaries
		return item;
	} else {
		// Could be anything
		return nil;
	}
}

- (NSString*) filenameForItem: (id) item {
	// Given an item in the outline view, work out the filename that it refers to
	NSDictionary* itemInfo = [self itemForItem: item];
	if (itemInfo == nil) return nil;
	
	return [itemInfo objectForKey: @"Filename"];
}

- (int) lineForItem: (id) item {
	// Given an item in the outline view, work out the line number that it refers to
	NSDictionary* itemInfo = [self itemForItem: item];
	if (itemInfo == nil) return -1;
	
	if ([itemInfo objectForKey: @"Line"] == nil) return -1;
	
	return [[itemInfo objectForKey: @"Line"] intValue];
}

- (NSString*) titleForItem: (id) item {
	// Given an item in the outline view, work out the line number that it refers to
	NSDictionary* itemInfo = [self itemForItem: item];
	if (itemInfo == nil) return nil;
	
	return [itemInfo objectForKey: @"Title"];
}

@end
