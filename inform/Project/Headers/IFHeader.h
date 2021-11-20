//
//  IFHeader.h
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IFIntelSymbol;

/// Notification send when this heading has changed
extern NSNotificationName const IFHeaderChangedNotification;

///
/// Model class representing a header in the header browser.
///
/// We build a separate model of these to better facilitate animating between states under Leopard.
///
@interface IFHeader : NSObject

// Initialisation
/// Constructs a new header object
- (instancetype) initWithName: (NSString*) name
                       parent: (IFHeader*) parent
                     children: (NSArray<IFHeader*>*) children NS_DESIGNATED_INITIALIZER;

// Accessing values
/// The name of this header
@property (nonatomic, copy) NSString *headingName;
/// The parent of this header
@property (nonatomic, weak) IFHeader *parent;
/// The headings 'beneath' this one
@property (atomic, copy) NSArray<IFHeader*> *children;
/// The symbol for this heading
@property (atomic, strong) IFIntelSymbol *symbol;

@end
