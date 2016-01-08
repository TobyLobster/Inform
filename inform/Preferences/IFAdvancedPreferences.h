//
//  IFAdvancedPreferences.h
//  Inform
//
//  Created by Andrew Hunter on 12/10/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPreferencePane.h"


//
// Preference pane that contains options mainly intended for use by Inform 7 maintainers
//
@interface IFAdvancedPreferences : IFPreferencePane

// Actions
- (IBAction) setPreference: (id) sender;				// Causes this view to update its preferences based on the values of the buttons
- (void) reflectCurrentPreferences;						// Causes this view to update its preferences according to the current values set in the preferences

@end
