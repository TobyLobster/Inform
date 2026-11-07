//
//  IFHeader.m
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "IFHeader.h"

@implementation IFHeader {
    /// The name of this header
    NSString* headingName;
    /// The parent of this header (NOT RETAINED)
    __weak IFHeader* parent;
    /// The child headings for this heading
    NSMutableArray* children;
    /// The symbol that is associated with this heading
    IFIntelSymbol* symbol;
}

// Initialisation

- (instancetype) initWithName: (NSString*) name
                       parent: (IFHeader*) newParent
                     children: (NSArray*) newChildren {
	self = [super init];
	
	if (self) {
        NSAssert(name != NULL, @"Null name passed to initWithName:parent:children:");
		headingName = [name copy];
		parent = newParent;
		
		if (newChildren) {
			children = [[NSMutableArray alloc] initWithArray: newChildren
												   copyItems: NO];
		} else {
			children = [[NSMutableArray alloc] init];
		}
		
		for(IFHeader* child in children) {
			child.parent = self;
		}
	}
	
	return self;
}

// Accessing values

@synthesize headingName;
@synthesize parent;

- (NSArray*) children {
	return [children copy];
}

@synthesize symbol;

- (void) setChildren: (NSArray*) newChildren {
    for(IFHeader* child in children) {
		[child setParent: nil];
	}

	children = [[NSMutableArray alloc] initWithArray: newChildren
										   copyItems: NO];
	
    for(IFHeader* child in children) {
		child.parent = self;
	}
}

@end
