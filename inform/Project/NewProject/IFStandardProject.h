//
//  IFStandardProject.h
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IFProjectType.h"

@class IFStandardProjectView;

//
// Project type that creates an Inform 6 project with a simple initial source file
//
@interface IFStandardProject : NSObject<IFProjectType> {
    IFStandardProjectView* vw;
    NSRange initialSelectionRange;
}
- (void) setInitialFocus:(NSWindow *)window;

@end

//
// Setup view for a standard Inform 6 project
//
@interface IFStandardProjectView : NSObject<IFProjectSetupView> {
    IBOutlet NSTextField* name;						// Field that contains the initial name of the game
    IBOutlet NSTextField* headline;					// Field that contains the games initial headline
    IBOutlet NSTextView*  teaser;					// Field that contains the games initial teaser
    IBOutlet NSTextField* initialRoom;				// Field that contains the name of the games initial room
    IBOutlet NSTextView*  initialRoomDescription;	// Field that contains the description of the games initial room

    IBOutlet NSView*      view;						// View that contains the lot
}

- (NSString*) name;
- (NSString*) headline;
- (NSString*) teaser;
- (NSString*) initialRoom;
- (NSString*) initialRoomDescription;

- (NSView*)   view;
- (void) setInitialFocus:(NSWindow *)window;

@end
