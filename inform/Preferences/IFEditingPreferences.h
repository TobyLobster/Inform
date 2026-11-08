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

/// The pane for the shared preferences
- (instancetype) init;
- (instancetype) initWithNibName: (NSString*) nibName NS_UNAVAILABLE;
/// The pane for the preferences given
- (instancetype) initWithPreferences: (IFPreferences*) preferences NS_DESIGNATED_INITIALIZER;

/// Puts back the default editing preferences, apart from the text size
- (void) restoreDefaults;

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (nullable id) sender;
- (void) reflectCurrentPreferences;
- (IBAction) restoreDefaultSettings: (nullable id) sender;

@end

NS_ASSUME_NONNULL_END
