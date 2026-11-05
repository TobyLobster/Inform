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

@interface IFAppDelegate : NSObject<NSOpenSavePanelDelegate, NSMenuItemValidation>

@property (atomic, readonly, nullable) IFNewsManager* newsManager;    // nil until the app has finished launching

/// Retrieves the runloop used by the main thread (Cocoa sometimes calls our callbacks
/// from a sooper-sekrit bonus thread, causing pain if we don't use this)
+ (nullable NSRunLoop*) mainRunLoop;
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

/// Updates extensions menu
- (void) updateExtensionsMenu;
- (void) createNewProject: (NSString*) title
                    story: (NSString*) story;
- (IBAction) installLegacyExtension: (nullable id) sender;
@property (NS_NONATOMIC_IOSONLY, readonly, strong, nullable) IFProjectController *frontmostProjectController;

// Spell checking
@property (atomic, readonly) BOOL sourceSpellChecking;
- (IBAction) toggleSourceSpellChecking: (nullable id) sender;

@end

NS_ASSUME_NONNULL_END
