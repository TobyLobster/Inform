//
//  IFColourPreferences.h
//  Inform
//
//  Created by Toby Nelson in 2022
//

#import <Cocoa/Cocoa.h>

#import "IFColourTheme.h"
#import "IFPreferencePane.h"

///
/// Preference pane that allows the user to select colours
///
@interface IFColourPreferences : IFPreferencePane

// Receiving data from/updating the interface
- (IBAction) styleSetHasChanged: (id) sender;
- (IBAction) restoreDefaultSettings: (id) sender;
- (IBAction) newStyle: (id) sender;
- (IBAction) deleteStyle: (id) sender;
- (IBAction) differentThemeChosen: (id) sender;

@end
