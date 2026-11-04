//
//  IFEditingPreferences.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

#import "IFEditingPreferencesSet.h"
#import "IFPreferencePane.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Preference pane that allows the user to select the styles she wants to see
///
@interface IFEditingPreferences : IFPreferencePane

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (nullable id) sender;
- (void) reflectCurrentPreferences;
- (IBAction) restoreDefaultSettings: (nullable id) sender;

@end

NS_ASSUME_NONNULL_END
