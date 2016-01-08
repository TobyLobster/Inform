//
//  IFAppDelegate.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Application delegate class

#import <Cocoa/Cocoa.h>

@interface IFAppDelegate : NSObject<NSOpenSavePanelDelegate>

+ (NSRunLoop*) mainRunLoop;							// Retrieves the runloop used by the main thread (Cocoa sometimes calls our callbacks from a sooper-sekrit bonus thread, causing pain if we don't use this)
- (void) doCopyProject: (NSURL*) source
                    to: (NSURL*) destination;

- (IBAction) showInspectors: (id) sender;			// Displays/hides the inspector window
- (IBAction) showPreferences: (id) sender;			// Shows the preferences window
- (IBAction) docIndex: (id) sender;					// Displays an error about not being able to show help yet

- (IBAction) showFind2: (id) sender;				// Shows the Find dialog
- (IBAction) findNext: (id) sender;					// 'Find next'
- (IBAction) findPrevious: (id) sender;				// 'Find previous'
- (IBAction) useSelectionForFind: (id) sender;		// 'Use selection for find'

- (IBAction) newProject: (id) sender;
- (IBAction) newExtension: (id) sender;
- (IBAction) newInform6Project: (id) sender;

- (IBAction) visitWebsite: (id) sender;
- (IBAction) showWelcome: (id) sender;
- (IBAction) exportToEPub: (id) sender;

- (void) updateExtensionsMenu;                      // Updates extensions menu

@property (atomic, readonly, copy) NSMenuItem *debugMenu;   // The Debug menu

// Spell checking
@property (atomic, readonly) BOOL sourceSpellChecking;
- (IBAction) toggleSourceSpellChecking: (id) sender;

@end
