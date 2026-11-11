//
//  IFColourPreferences.h
//  Inform
//
//  Created by Toby Nelson in 2022
//

#import <Cocoa/Cocoa.h>

#import "IFColourTheme.h"
#import "IFPreferencePane.h"

NS_ASSUME_NONNULL_BEGIN

///
/// Preference pane that allows the user to select colours
///
@interface IFColourPreferences : IFPreferencePane

/// The pane for the shared preferences
- (instancetype) init;
- (instancetype) initWithNibName: (NSString*) nibName NS_UNAVAILABLE;
/// The pane for the preferences given
- (instancetype) initWithPreferences: (IFPreferences*) preferences NS_DESIGNATED_INITIALIZER;

/// Adds a copy of the current theme with the name given, which can be deleted, and makes it the current theme.
/// NO, changing nothing, if a theme already has the name.
- (BOOL) addThemeNamed: (NSString*) name;
/// Deletes the current theme, if it can be deleted, and makes Light Mode the current theme
- (void) deleteCurrentTheme;
/// Puts back the current theme's default colours, and colours syntax
- (void) restoreDefaults;
/// The sheet New shows, ready to be shown, with a name no theme has in its name field
- (nullable NSWindow*) newThemeSheet;

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (nullable id) sender;
- (IBAction) restoreDefaultSettings: (nullable id) sender;
- (IBAction) newStyle: (nullable id) sender;
- (IBAction) deleteStyle: (nullable id) sender;
- (IBAction) differentThemeChosen: (nullable id) sender;

@end

NS_ASSUME_NONNULL_END
