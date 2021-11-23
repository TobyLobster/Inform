//
//  IFSettingsPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"


///
/// The 'settings' page
///
@interface IFSettingsPage : IFPage

// Settings
/// Updates the settings views with their current values
- (void) updateSettings;

- (instancetype) initWithProjectController: (IFProjectController*) controller;

@end
