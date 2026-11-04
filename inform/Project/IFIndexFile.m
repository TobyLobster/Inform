//
//  IFIndexFile.m
//  Inform
//
//  Created by Andrew Hunter on Sun Jun 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "IFIndexFile.h"


@implementation IFIndexFile {
    NSDictionary<NSString*,id>* index;

    NSMutableDictionary* filenamesToIndexes;
}

- (instancetype) initWithContentsOfFile: (NSString*) filename {
    NSError *err;
	self = [self initWithContentsOfURL: [NSURL fileURLWithPath: filename]
                                 error: &err];
    if (!self) {
        NSLog(@"IFIndexFile: found no data: %@", err);
    }
    
	return self;
}

- (instancetype) initWithContentsOfURL: (NSURL*) filename error: (NSError*__autoreleasing*) outError {
    NSData *dat = [NSData dataWithContentsOfURL: filename
                                        options: NSDataReadingMappedIfSafe
                                          error: outError];
    
    if (!dat) {
        return nil;
    }
    
    return [self initWithData: dat error: outError];
}

- (instancetype) initWithData: (NSData*) data {
    NSError *err;
    self = [self initWithData: data error: &err];
    
    if (!self) {
        NSLog(@"IFIndexFile: found no data: %@", err);
    }
    return self;
}

- (instancetype) initWithData: (NSData*) data error: (NSError* __autoreleasing*) outError {
	self = [super init];
	
	if (self) {
		if (data == nil) {
            if (outError) {
                *outError = [NSError errorWithDomain: NSOSStatusErrorDomain
                                                code: paramErr
                                            userInfo: nil];
            }
			return nil;
		}
		
		// Data is provided as a property list file, which makes things easy for us to parse
		// Req 10.2 (surely no-one is still seriously using 10.1?)
		NSPropertyListFormat format;
		
		id plist =  [NSPropertyListSerialization propertyListWithData: data
                                                              options: NSPropertyListImmutable
                                                               format: &format
                                                                error: outError];
		
		// Sanity check
		if (plist == nil) {
			return nil;
		}
		
		if (![plist isKindOfClass: [NSDictionary class]]) {
            if (outError) {
                *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                                code: NSFileReadCorruptFileError
                                            userInfo: @{
                    NSLocalizedDescriptionKey: @"property list does not contain a dictionary"
                }];
            }
			return nil;
		}
		
		// OK: we've got an index in plist. Do some processing...
		index = [plist copy];
		
		// Need the keys sorted by numeric value to make any sense of them
		NSMutableArray* orderedKeys = [index.allKeys mutableCopy];
        [orderedKeys sortUsingComparator:^NSComparisonResult(id  _Nonnull a, id  _Nonnull b) {
            int aV = [a intValue];
            int bV = [b intValue];
            
            if (aV < bV) return NSOrderedAscending;
            if (aV > bV) return NSOrderedDescending;
            return NSOrderedSame;
        }];
		
		// Turn the index into a hierarchical dictionary
		// Top level indexed by filenames
		filenamesToIndexes = [[NSMutableDictionary alloc] init];
		
		for( NSString* key in orderedKeys ) {
			NSDictionary* item = index[key];
			
			if ([item isKindOfClass: [NSDictionary class]] &&
				item[@"Filename"] != nil &&
				item[@"Indentation"] != nil &&
				item[@"Level"] != nil &&
				item[@"Line"] != nil &&
				item[@"Title"] != nil) {
				NSString* filename = item[@"Filename"];
				int indent = [item[@"Indentation"] intValue];
				int line   = [item[@"Line"] intValue];
				NSString* title = item[@"Title"];
				
				// HACK: only include the source files
				if (![filename.stringByDeletingLastPathComponent.lastPathComponent isEqualToString: @"Source"]) continue;
				
				// Get the initial index for this file
				NSMutableArray* indexForFilename = filenamesToIndexes[filename];
				if (indexForFilename == nil) {
					indexForFilename = [[NSMutableArray alloc] init];
					filenamesToIndexes[filename] = indexForFilename;
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
					title, @"Title", @(line), @"Line", 
					filename, @"Filename", nil];
				
				// Iterate down to the lowest item
				NSMutableArray* indexToAdd = indexForFilename;
				int x;
				for (x=0; x<indent; x++) {
					NSMutableArray* newIndex = indexToAdd.lastObject[@"Contents"];
					if (newIndex == nil) {
						if (indexToAdd.lastObject == nil) {
							NSLog(@"IFIndexFile BUG: found an empty index");
							break;
						}
						
						// Need to add a new level
						newIndex = [[NSMutableArray alloc] init];
						indexToAdd.lastObject[@"Contents"] = newIndex;
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


// == We can be an NSOutlineView data source ==

- (id)outlineView: (NSOutlineView *)outlineView 
			child: (NSInteger)childIndex
		   ofItem: (id)item {
	if (item == nil) {
		// Root item
		NSArray* allKeys = filenamesToIndexes.allKeys;
		
		if (childIndex >= allKeys.count) return @"";
		
		return allKeys[childIndex];
	} else if ([item isKindOfClass: [NSString class]]) {
		// Happens with the filename indexes only...
		NSArray* filenameIndex = filenamesToIndexes[item];
		
		if (childIndex >= filenameIndex.count) return @"";
		
		return filenameIndex[childIndex];
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		NSMutableArray* contents = itemDictionary[@"Contents"];
		
		if (childIndex >= contents.count) return @"";
		
		return contents[childIndex];
	}
}

- (BOOL)outlineView: (NSOutlineView *)outlineView
   isItemExpandable: (id)item {
	if (item == nil) {
		// Root item
		return YES;
	} else if ([item isKindOfClass: [NSString class]]) {
		// Happens with the filename indexes only...
		NSArray* filenameIndex = filenamesToIndexes[item];

		if (filenameIndex.count <= 0)
			return NO;
		else
			return YES;
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		NSMutableArray* contents = itemDictionary[@"Contents"];
		
		if (contents == nil || contents.count <= 0) 
			return NO;
		else
			return YES;
	}
}

- (NSInteger)	outlineView:(NSOutlineView *)outlineView
	 numberOfChildrenOfItem:(id)item {
	if (item == nil) {
		// Root item
		NSArray* allKeys = filenamesToIndexes.allKeys;
		
		return allKeys.count;
	} else if ([item isKindOfClass: [NSString class]]) {
		// Happens with the filename indexes only...
		NSArray* filenameIndex = filenamesToIndexes[item];
		
		return filenameIndex.count;
	} else {
		// Is an item dictionary
		NSDictionary* itemDictionary = item;
		NSMutableArray* contents = itemDictionary[@"Contents"];
		
		if (contents == nil || contents.count <= 0) 
			return 0;
		else
			return (int) contents.count;
	}
}

- (id)				outlineView:(NSOutlineView *)outlineView 
	  objectValueForTableColumn:(NSTableColumn *)tableColumn
						 byItem:(id)item {
	// Valid column identifiers are 'title' and 'line'
	NSString* identifier = tableColumn.identifier;
	
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
			return itemDictionary[@"Title"];
		} else if ([identifier isEqualToString: @"line"]) {
			return itemDictionary[@"Line"];
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
		return @{@"Filename": item, @"Title": item}; // Note: no line numbers
	} else if ([item isKindOfClass: [NSDictionary class]]) {
		// 'Normal' items are NSDictionaries
		return item;
	} else {
		// Could be anything
		return nil;
	}
}

/// Given an item in the outline view, work out the filename that it refers to
- (NSString*) filenameForItem: (id) item {
	NSDictionary* itemInfo = [self itemForItem: item];
	if (itemInfo == nil) return nil;
	
	return itemInfo[@"Filename"];
}

/// Given an item in the outline view, work out the file URL that it refers to
- (NSURL*) fileURLForItem: (id) item {
    NSString *filename = [self filenameForItem:item];
    if (filename == nil) {
        return nil;
    }
    
    return [NSURL fileURLWithPath: filename];
}

/// Given an item in the outline view, work out the line number that it refers to
- (int) lineForItem: (id) item {
	NSDictionary* itemInfo = [self itemForItem: item];
	if (itemInfo == nil) return -1;
	
	if (itemInfo[@"Line"] == nil) return -1;
	
	return [itemInfo[@"Line"] intValue];
}

/// Given an item in the outline view, work out the line number that it refers to
- (NSString*) titleForItem: (id) item {
	NSDictionary* itemInfo = [self itemForItem: item];
	if (itemInfo == nil) return nil;
	
	return itemInfo[@"Title"];
}

@end
