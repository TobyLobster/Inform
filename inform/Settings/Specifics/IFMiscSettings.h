//
//  IFMiscSettings.h
//  Inform
//
//  Created by Andrew Hunter on 10/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFSetting.h"

//
// Some miscellaneous Inform 6 settings
//
@interface IFMiscSettings : IFSetting {
    IBOutlet NSButton* strictMode;
    IBOutlet NSButton* infixMode;
    IBOutlet NSButton* debugMode;	
}

- (void) setStrict: (BOOL) setting;
- (void) setInfix: (BOOL) setting;
- (void) setDebug: (BOOL) setting;
- (BOOL) strict;
- (BOOL) infix;
- (BOOL) debug;

@end
