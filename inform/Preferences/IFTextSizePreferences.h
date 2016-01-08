//
//  IFTextSizePreferences.h
//  Inform
//
//  Created by Toby Nelson on 2014.
//

#import <Cocoa/Cocoa.h>

#import "IFPreferencePane.h"

@interface IFTextSizePreferences : IFPreferencePane

// Receiving data from/updating the interface
- (IBAction) setPreference: (id) sender;
- (void) reflectCurrentPreferences;

@end
