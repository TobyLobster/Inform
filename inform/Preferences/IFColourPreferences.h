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

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (nullable id) sender;
- (IBAction) restoreDefaultSettings: (nullable id) sender;
- (IBAction) newStyle: (nullable id) sender;
- (IBAction) deleteStyle: (nullable id) sender;
- (IBAction) differentThemeChosen: (nullable id) sender;

@end

NS_ASSUME_NONNULL_END
