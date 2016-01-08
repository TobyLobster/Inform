//
//  IFAuthorPreferences.h
//  Inform
//
//  Created by Andrew Hunter on 18/10/2009.
//  Copyright 2009 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFPreferencePane.h"

@interface IFAuthorPreferences : IFPreferencePane

// Receiving data from/updating the interface
- (IBAction) setPreference: (id) sender;
- (void) reflectCurrentPreferences;

@end
