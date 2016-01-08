//
//  IFNewStandardProject.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFNewProjectProtocol.h"

@class IFNewInform6ProjectView;

//
// Project type that creates an Inform 6 project with a simple initial source file
//
@interface IFNewInform6Project : NSObject<IFNewProjectProtocol>

- (void) setInitialFocus:(NSWindow *)window;

@end

//
// Setup view for a standard Inform 6 project
//
@interface IFNewInform6ProjectView : NSObject<IFNewProjectSetupView>

@property (atomic, readonly, copy) NSString *name;
@property (atomic, readonly, copy) NSString *headline;
@property (atomic, readonly, copy) NSString *teaser;
@property (atomic, readonly, copy) NSString *initialRoom;
@property (atomic, readonly, copy) NSString *initialRoomDescription;

@property (atomic, readonly, strong) NSView *view;
- (void) setInitialFocus:(NSWindow *)window;

@end
