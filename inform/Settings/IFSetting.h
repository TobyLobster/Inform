//
//  IFSetting.h
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Notification strings
extern NSNotificationName const IFSettingHasChangedNotification;

@class IFCompilerSettings;

//
// Representation of a class of settings
// Technically a controller object
//
// It's usually pretty pointless to make extra model objects beyond IFCompilerSettings, so there
// may be some overlap with the model here.
//
@interface IFSetting : NSObject

- (instancetype) initWithNibName: (NSString*) nibName NS_DESIGNATED_INITIALIZER;    // Initialises the setting object, and loads the given nib

// Setting up the view
/// The settings view
@property (atomic, strong) IBOutlet NSView *settingView;

// Information about this settings view
@property (atomic, readonly, copy) NSString *title;		// (OVERRIDE) Retrieves the title for these settings

// Setting/retrieving the model
@property (atomic, strong) IFCompilerSettings *compilerSettings;    // The compiler settings object that this setting will use
- (NSMutableDictionary*) dictionary;                                // Retrieves the settings dictionary for this object

// Communicating with the IFCompilerSettings object
- (void) setSettings;												// (OVERRIDE) Sets values in the compiler settings (or the dictionary) from the current UI choices
- (BOOL) enableForCompiler: (NSString*) compiler;					// YES if this set of settings applies to the given compiler type (IFCompilerInform6 or IFCompilerNaturalInform)
- (void) updateFromCompilerSettings;								// (OVERRIDE) Sets values in the UI from the values set in the compiler settings (or the dictionary)

// Notifying the controller about things
- (IBAction) settingsHaveChanged: (id) sender;						// Action called when the user changes a setting option

// Saving settings
@property (atomic, readonly, copy) NSDictionary *plistEntries;		// Retrieves the Plist dictionary for this setting
- (void) updateSettings: (IFCompilerSettings*) settings             // Updates the values for this setting from a Plist dictionary
	   withPlistEntries: (NSDictionary*) entries;

@end
