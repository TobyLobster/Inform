//
//  IFHeader.m
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHeader.h"


NSString* IFHeaderChangedNotification = @"IFHeaderChangedNotification";

@implementation IFHeader {
    NSString* headingName;						// The name of this header
    IFHeader* parent;							// The parent of this header (NOT RETAINED)
    NSMutableArray* children;					// The child headings for this heading
    IFIntelSymbol* symbol;						// The symbol that is associated with this heading
}

// Initialisation

- (instancetype) init {
	return [self initWithName: @""
					   parent: nil
					 children: nil];
}

- (instancetype) initWithName: (NSString*) name
			 parent: (IFHeader*) newParent
		   children: (NSArray*) newChildren {
	self = [super init];
	
	if (self) {
		headingName = [name copy];
		parent = newParent;
		
		if (newChildren) {
			children = [[NSMutableArray alloc] initWithArray: newChildren
												   copyItems: NO];
		} else {
			children = [[NSMutableArray alloc] init];
		}
		
		for(IFHeader* child in children) {
			[child setParent: self];
		}
	}
	
	return self;
}

- (void) dealloc {
    for(IFHeader* child in children) {
		[child setParent: nil];
	}
}

// Accessing values

- (void) hasChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: IFHeaderChangedNotification
														object: self];
}

- (NSString*) headingName {
	return headingName;
}

- (IFHeader*) parent {
	return parent;
}

- (NSArray*) children {
	return children;
}

- (IFIntelSymbol*) symbol {
	return symbol;
}

- (void) setHeadingName: (NSString*) newName {
	headingName = newName;
	
	[self hasChanged];
}

- (void) setParent: (IFHeader*) newParent {
	if (newParent == parent) return;
	
	parent = newParent;
	[self hasChanged];
}

- (void) setChildren: (NSArray*) newChildren {
    for(IFHeader* child in children) {
		[child setParent: nil];
	}

	if (newChildren) {
		children = [[NSMutableArray alloc] initWithArray: newChildren
											   copyItems: NO];
	} else {
		children = [[NSMutableArray alloc] init];
	}
	
    for(IFHeader* child in children) {
		[child setParent: self];
	}
	
	[self hasChanged];
}

- (void) setSymbol: (IFIntelSymbol*) newSymbol {
	symbol = newSymbol;
}

@end
