//
//  IFSettingsPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"


//
// The 'settings' page
//
@interface IFSettingsPage : IFPage

// Settings
- (void) updateSettings;										// Updates the settings views with their current values

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
