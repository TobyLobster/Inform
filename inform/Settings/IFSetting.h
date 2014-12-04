//
//  IFSetting.h
//  Inform
//
//  Created by Andrew Hunter on 06/10/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Notification strings
extern NSString* IFSettingHasChangedNotification;

@class IFCompilerSettings;

//
// Representation of a class of settings
// Technically a controller object
//
// It's usually pretty pointless to make extra model objects beyond IFCompilerSettings, so there
// may be some overlap with the model here.
//
@interface IFSetting : NSObject {
	IBOutlet NSView* settingView;					// The view that can be used to edit the settings
	
	IFCompilerSettings* compilerSettings;			// The compiler settings object that this setting should manage (compiler settings are not retained to avoid a retention loop)
	
	BOOL settingsChanging;							// YES if the settings are in the process of changing
}

- (id) initWithNibName: (NSString*) nibName;							// Initialises the setting object, and loads the given nib

// Setting up the view
- (NSView*) settingView;												// Retrieves the settings view
- (void) setSettingView: (NSView*) settingView;				// Sets the settings view

// Information about this settings view
- (NSString*) title;													// (OVERRIDE) Retrieves the title for these settings

// Setting/retrieving the model
- (void) setCompilerSettings: (IFCompilerSettings*) compilerSettings;	// (NOT RETAINED) Sets the compiler settings object to use
- (IFCompilerSettings*) compilerSettings;								// Retrieves the compiler settings object that this setting will use
- (NSMutableDictionary*) dictionary;									// Retrieves the settings dictionary for this object

// Communicating with the IFCompilerSettings object
- (void) setSettings;													// (OVERRIDE) Sets values in the compiler settings (or the dictionary) from the current UI choices
- (BOOL) enableForCompiler: (NSString*) compiler;						// YES if this set of settings applies to the given compiler type (IFCompilerInform6 or IFCompilerNaturalInform)
- (NSArray*) commandLineOptionsForCompiler: (NSString*) compiler;		// Retrieves the command line options that should be applied for this setting for the given compiler type
- (NSArray*) includePathForCompiler: (NSString*) compiler;				// Retrieves the include directories to use for this setting for the given compiler type
- (void) updateFromCompilerSettings;									// (OVERRIDE) Sets values in the UI from the values set in the compiler settings (or the dictionary)

// Notifying the controller about things
- (IBAction) settingsHaveChanged: (id) sender;							// Action called when the user changes a setting option

// Saving settings
- (NSDictionary*) plistEntries;											// Retrieves the Plist dictionary for this setting
- (void) updateSettings: (IFCompilerSettings*) settings					// Updates the values for this setting from a Plist dictionary
	   withPlistEntries: (NSDictionary*) entries;

@end

#import "IFCompilerSettings.h"
