//
//  IFAppDelegate.h
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

// Application delegate class

#import <Cocoa/Cocoa.h>

@interface IFAppDelegate : NSObject<NSOpenSavePanelDelegate> {
	BOOL haveWebkit;								// YES if webkit is installed (NO otherwise; only really does anything on early 10.2 versions, and we don't support them any more)
	
	IBOutlet NSMenuItem* extensionsMenu;			// The 'Open Extension' menu
	IBOutlet NSMenuItem* debugMenu;					// The Debug menu
	
	NSMutableArray* extensionSources;				// Maps extension menu tags to source file names
	
	NSOpenPanel* openExtensionPanel;				// The 'open extension' panel

    // Used for copying sample projects
    NSURL*   copySource;
    NSURL*   copyDestination;
    
    // Used for copying resource files (e.g. epubs)
    NSString* fileCopyDestination;
    NSString* fileCopySource;
    int exportToEPubIndex;
}

+ (NSRunLoop*) mainRunLoop;							// Retrieves the runloop used by the main thread (Cocoa sometimes calls our callbacks from a sooper-sekrit bonus thread, causing pain if we don't use this)
+ (BOOL) isWebKitAvailable;							// YES if WebKit is around
- (void) doCopyProject: (NSURL*) source
                    to: (NSURL*) destination;

- (BOOL)isWebKitAvailable;							// YES if WebKit is around

- (IBAction) showInspectors: (id) sender;			// Displays/hides the inspector window
- (IBAction) newHeaderFile: (id) sender;			// Creates a new .h file (in a new window)
- (IBAction) newInformFile: (id) sender;			// Creates a new .inf file (in a new window)
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

- (NSMenuItem*) debugMenu;							// The Debug menu

// Spell checking
- (BOOL) sourceSpellChecking;
- (IBAction) toggleSourceSpellChecking: (id) sender;

@end
