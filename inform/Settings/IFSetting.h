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

///
/// Representation of a class of settings
/// Technically a controller object
///
/// It's usually pretty pointless to make extra model objects beyond IFCompilerSettings, so there
/// may be some overlap with the model here.
///
@interface IFSetting : NSObject

/// Initialises the setting object, and loads the given nib
- (instancetype) initWithNibName: (NSString*) nibName NS_DESIGNATED_INITIALIZER;

// Setting up the view
/// The settings view
@property (atomic, strong) IBOutlet NSView *settingView;

// Information about this settings view
@property (atomic, readonly, copy) NSString *title;		// (OVERRIDE) Retrieves the title for these settings

// Setting/retrieving the model
/// The compiler settings object that this setting will use
@property (atomic, strong) IFCompilerSettings *compilerSettings;
/// Retrieves the settings dictionary for this object
- (NSMutableDictionary*) dictionary;

// Communicating with the IFCompilerSettings object
/// (OVERRIDE) Sets values in the compiler settings (or the dictionary) from the current UI choices
- (void) setSettings;
/// \c YES if this set of settings applies to the given compiler type (IFCompilerInform6 or IFCompilerNaturalInform)
- (BOOL) enableForCompiler: (NSString*) compiler;
/// (OVERRIDE) Sets values in the UI from the values set in the compiler settings (or the dictionary)
- (void) updateFromCompilerSettings;

// Notifying the controller about things
/// Action called when the user changes a setting option
- (IBAction) settingsHaveChanged: (id) sender;

// Saving settings
/// Retrieves the Plist dictionary for this setting
@property (atomic, readonly, copy) NSDictionary *plistEntries;
/// Updates the values for this setting from a Plist dictionary
- (void) updateSettings: (IFCompilerSettings*) settings
	   withPlistEntries: (NSDictionary*) entries;

@end
