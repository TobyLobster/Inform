//
//  IFAuthorPreferences.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPreferencePane.h"

@interface IFAuthorPreferences : IFPreferencePane {
	IBOutlet NSTextField* newGameName;					// The preferred name for new Natural Inform games
}

// Receiving data from/updating the interface
- (IBAction) setPreference: (id) sender;
- (void) reflectCurrentPreferences;

@end
