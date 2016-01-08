//
//  IFHeader.h
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFIntelSymbol;

extern NSString* IFHeaderChangedNotification;	// Notification send when this heading has changed

///
/// Model class representing a header in the header browser.
///
/// We build a separate model of these to better facilitate animating between states under Leopard.
///
@interface IFHeader : NSObject

// Initialisation
- (instancetype) initWithName: (NSString*) name			// Constructs a new header object
			 parent: (IFHeader*) parent
		   children: (NSArray*) children NS_DESIGNATED_INITIALIZER;

// Accessing values
@property (atomic, copy) NSString *headingName;							// The name of this header
@property (atomic, strong) IFHeader *parent;							// The parent of this header
@property (atomic, copy) NSArray *children;								// The headings 'beneath' this one
@property (atomic, strong) IFIntelSymbol *symbol;						// The symbol for this heading

@end
