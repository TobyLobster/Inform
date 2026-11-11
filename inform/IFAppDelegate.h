//
//  IFAppDelegate.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Application delegate class

#import <Cocoa/Cocoa.h>
#import "IFNewsManager.h"

NS_ASSUME_NONNULL_BEGIN

@class IFProjectController;

NS_SWIFT_UI_ACTOR
@interface IFAppDelegate : NSObject<NSMenuItemValidation>

/// The app's delegate, made by the main menu's nib, which keeps whether the source is spell checked in the user's defaults
- (instancetype) init;
/// An app delegate that keeps whether the source is spell checked in the given defaults
- (instancetype) initWithDefaults: (NSUserDefaults*) defaults NS_DESIGNATED_INITIALIZER;

@property (atomic, readonly, nullable) IFNewsManager* newsManager;    // nil until the app has finished launching

- (void) doCopyProject: (NSURL*) source
                    to: (NSURL*) destination;

/// Shows the About panel, including the Inform compiler version
- (IBAction) showAbout: (nullable id) sender;
/// Shows the preferences window
- (IBAction) showPreferences: (nullable id) sender;
/// Displays an error about not being able to show help yet
- (IBAction) docIndex: (nullable id) sender;

/// Shows the Find dialog
- (IBAction) showFind2: (nullable id) sender;
/// 'Find next'
- (IBAction) findNext: (nullable id) sender;
/// 'Find previous'
- (IBAction) findPrevious: (nullable id) sender;
/// 'Use selection for find'
- (IBAction) useSelectionForFind: (nullable id) sender;

- (IBAction) newProject: (nullable id) sender;
- (IBAction) newExtension: (nullable id) sender;

- (IBAction) visitWebsite: (nullable id) sender;
- (IBAction) showWelcome: (nullable id) sender;
- (IBAction) exportToEPub: (nullable id) sender;

/// Updates the extensions menus with the extensions installed for a version of the compiler
- (void) updateExtensionsMenuForCompilerVersion: (NSString*) compilerVersion;
- (void) createNewProject: (NSString*) title
                    story: (NSString*) story;
- (IBAction) installLegacyExtension: (nullable id) sender;
@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) IFProjectController *frontmostProjectController;

// Spell checking
@property (atomic, readonly) BOOL sourceSpellChecking;
- (IBAction) toggleSourceSpellChecking: (nullable id) sender;

@end

NS_ASSUME_NONNULL_END
