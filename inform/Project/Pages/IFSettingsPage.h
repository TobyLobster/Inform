//
//  IFSettingsPage.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"


//
// The 'settings' page
//
@interface IFSettingsPage : IFPage {
    // Settings
	IBOutlet IFSettingsView* settingsView;				// The settings view
	IBOutlet IFSettingsController* settingsController;	// The settings controller	
}

// Settings
- (void) updateSettings;										// Updates the settings views with their current values

- (id) initWithProjectController: (IFProjectController*) controller;

@end
