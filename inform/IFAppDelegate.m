//
//  IFAppDelegate.m
//  Inform
//
//  Created by Andrew Hunter on Mon Aug 18 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFAppDelegate.h"
#import "IFCompilerController.h"
#import "IFNewProject.h"
#import "IFInspectorWindow.h"
#import "IFExtensionsManager.h"
#import "IFWelcomeWindow.h"
#import "IFFindController.h"
#import "IFFindInFilesController.h"
#import "IFMaintenanceTask.h"

#import "IFProject.h"
#import "IFProjectController.h"

#import "IFIsNotes.h"
#import "IFIsIndex.h"
#import "IFIsFiles.h"
#import "IFIsWatch.h"
#import "IFIsBreakpoints.h"

#import "Preferences/IFPreferenceController.h"
#import "Preferences/IFAuthorPreferences.h"
#import "Preferences/IFEditingPreferences.h"
#import "Preferences/IFTextSizePreferences.h"
#import "Preferences/IFAdvancedPreferences.h"

#import "IFNoDocProtocol.h"
#import "IFInformProtocol.h"

#import "IFSettingsController.h"
#import "IFMiscSettings.h"
#import "IFOutputSettings.h"
#import "IFI7OutputSettings.h"
#import "IFRandomSettings.h"
#import "IFCompilerOptions.h"
#import "IFLibrarySettings.h"
#import "IFDebugSettings.h"

#import "IFSingleFile.h"
#import "IFPreferences.h"
#import "IFProject.h"
#import "IFImageCache.h"
#import "IFUtility.h"

#import "IFSkeinItemView.h"

#import "IFSingleController.h"

#import <GlkView/GlkHub.h>

@implementation IFAppDelegate {
    IBOutlet NSMenuItem* newExtensionProjectMenu;   // The 'New Extension Project' menu
    IBOutlet NSMenuItem* openExtensionMenu;         // The 'Open Extension' menu
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

static NSString* IFSourceSpellChecking = @"IFSourceSpellChecking";
static float     pixelWidthBetweenExtensionNameAndVersion = 10.0f;
static IFNewProject* newProj = nil;

static NSRunLoop* mainRunLoop = nil;
+ (NSRunLoop*) mainRunLoop {
	return mainRunLoop;
}

+ (BOOL)isWebKitAvailable {
    static BOOL _webkitAvailable=NO;
    static BOOL _initialized=NO;
    
    if (_initialized)
        return _webkitAvailable;
	
    NSBundle* webKitBundle;
    webKitBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/WebKit.framework"];
    if (webKitBundle) {
        _webkitAvailable = [webKitBundle load];
    }
    _initialized=YES;
    
    return _webkitAvailable;
}

- (void) applicationWillFinishLaunching: (NSNotification*) not {
	mainRunLoop = [NSRunLoop currentRunLoop];
	
    // Register some custom URL handlers
    // [NSURLProtocol registerClass: [IFNoDocProtocol class]];
    [NSURLProtocol registerClass: [IFInformProtocol class]];

    copySource = nil;
    copyDestination = nil;
    fileCopyDestination = nil;
    fileCopySource = nil;
    exportToEPubIndex = 0;

	// Standard settings
	[IFSettingsController addStandardSettingsClass: [IFOutputSettings class]];
	[IFSettingsController addStandardSettingsClass: [IFI7OutputSettings class]];
	[IFSettingsController addStandardSettingsClass: [IFRandomSettings class]];
	[IFSettingsController addStandardSettingsClass: [IFCompilerOptions class]];
	[IFSettingsController addStandardSettingsClass: [IFLibrarySettings class]];
	[IFSettingsController addStandardSettingsClass: [IFMiscSettings class]];

	// Glk hub
	[[GlkHub sharedGlkHub] setRandomHubCookie];
	[[GlkHub sharedGlkHub] setHubName: @"GlkInform"];
}

- (void) applicationDidFinishLaunching: (NSNotification*) not {	
	// The standard inspectors
	[[IFInspectorWindow sharedInspectorWindow] addInspector: [IFIsFiles sharedIFIsFiles]];
	[[IFInspectorWindow sharedInspectorWindow] addInspector: [IFIsNotes sharedIFIsNotes]];
	[[IFInspectorWindow sharedInspectorWindow] addInspector: [IFIsIndex sharedIFIsIndex]];
	[[IFInspectorWindow sharedInspectorWindow] addInspector: [IFIsWatch sharedIFIsWatch]];
	[[IFInspectorWindow sharedInspectorWindow] addInspector: [IFIsBreakpoints sharedIFIsBreakpoints]];
	
	// The standard preferences
	[[IFPreferenceController sharedPreferenceController] addPreferencePane: [[IFAuthorPreferences alloc] init]];
	[[IFPreferenceController sharedPreferenceController] addPreferencePane: [[IFEditingPreferences alloc] init]];
	[[IFPreferenceController sharedPreferenceController] addPreferencePane: [[IFTextSizePreferences alloc] init]];
	[[IFPreferenceController sharedPreferenceController] addPreferencePane: [[IFAdvancedPreferences alloc] init]];

	// Finish setting up
	[self updateExtensionsMenu];

	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(updateExtensionsMenu)
												 name: IFExtensionsUpdatedNotification
											   object: nil];

	[NSURLProtocol registerClass: [IFInformProtocol class]];

    // Schedule "Checking whether document exists." into next UI Loop, because document is not restored yet.
    NSInvocationOperation* op = [[NSInvocationOperation alloc] initWithTarget: self
                                                                     selector: @selector(openWelcomeDialogIfNeeded)
                                                                       object: nil];
    [[NSOperationQueue mainQueue] addOperation: op];
}

-(void)openWelcomeDialogIfNeeded
{
    //
    // HACK: Remove any open color panel. Lion's auto-restore of windows that were open when
    // the app last closed down can cause the color panel to display. We close the window.
    //
    if([NSColorPanel sharedColorPanelExists]) {
        [[NSColorPanel sharedColorPanel] close];
    }
    
    NSUInteger documentCount = [[[NSDocumentController sharedDocumentController] documents]count];
    
    // If no documents have opened, open the welcome dialog instead...
    if(documentCount == 0) {
        [IFWelcomeWindow showWelcomeWindow];
    }
}

- (BOOL) applicationShouldOpenUntitledFile: (NSApplication*) sender {
    [IFWelcomeWindow showWelcomeWindow];

    return NO;
}

- (void) doCopyProject: (NSURL*) source
                    to: (NSURL*) destination {
    NSURL* materialsDestination = [[destination URLByDeletingPathExtension] URLByAppendingPathExtension: @"materials"];

    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: [destination path]] ||
                  [[NSFileManager defaultManager] fileExistsAtPath: [materialsDestination path]];

    if( exists ) {
        copySource = source;
        copyDestination = destination;
        
        // Ask for confirmation
        NSString* confirm = [NSString stringWithFormat: [IFUtility localizedString: @"Do you want to overwrite %@?"], [destination path]];
        [IFUtility runAlertYesNoWindow: nil
                                 title: [IFUtility localizedString: @"Are you sure?"]
                                   yes: [IFUtility localizedString: @"Overwrite"]
                                    no: [IFUtility localizedString: @"Cancel"]
                         modalDelegate: self
                        didEndSelector: @selector(confirmDidEnd:returnCode:contextInfo:)
                           contextInfo: nil
                               message: confirm];
        return;
    }

    [[self class] copyProjectWithoutConfirmation: source
                                              to: destination];
}

- (void) confirmDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	if (returnCode == NSAlertFirstButtonReturn) {
        [[self class] copyProjectWithoutConfirmation: copySource
                                                  to: copyDestination];
        copySource = nil;
        
        copyDestination = nil;
	}
}

+ (BOOL) copyProjectWithoutConfirmation: (NSURL*) source
                                     to: (NSURL*) destination {
    BOOL isDirectory = NO;
    NSError* error;

    // Delete the destination, then copy the .inform directory
    [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
    if (![[NSFileManager defaultManager] copyItemAtURL: source
                                                 toURL: destination
                                                 error: &error] ) {
        if( error != nil ) {
            [IFUtility runAlertWarningWindow: nil
                                       title: [IFUtility localizedString:@"Error"]
                                     message: @"%@", [error localizedDescription]];
        }
        return NO;
    }

    // Copy the associate .materials directory
    NSURL* materialsSource      = [[source URLByDeletingPathExtension]      URLByAppendingPathExtension: @"materials"];
    NSURL* materialsDestination = [[destination URLByDeletingPathExtension] URLByAppendingPathExtension: @"materials"];

    if( [[NSFileManager defaultManager] fileExistsAtPath: [materialsSource path]
                                             isDirectory: &isDirectory] ) {
        if( isDirectory ) {
            [[NSFileManager defaultManager] removeItemAtURL:materialsDestination error:nil];
            if (![[NSFileManager defaultManager] copyItemAtURL: materialsSource
                                                         toURL: materialsDestination
                                                         error: &error] ) {
                if( error != nil ) {
                    [IFUtility runAlertWarningWindow: nil
                                               title: [IFUtility localizedString:@"Error"]
                                             message: @"%@", [error localizedDescription]];
                }
                return NO;
            }
        }
    }
    
    // Open the project
    NSDocumentController* docControl = [NSDocumentController sharedDocumentController];
    
    [docControl openDocumentWithContentsOfURL: destination
                                      display: YES
                                        error: &error];

    return YES;
}

- (void) createNewProject: (NSString*) title
                    story: (NSString*) story {
    if( newProj == nil ) {
        newProj = [[IFNewProject alloc] init];
    }
    [newProj createInform7Project: title
                         fileType: IFFileTypeInform7Project
                            story: story];
}

- (IBAction) newProject: (id) sender {
    if( newProj == nil ) {
        newProj = [[IFNewProject alloc] init];
    }
    [newProj createInform7Project: nil
                         fileType: IFFileTypeInform7Project
                            story: nil];
}

- (IBAction) newExtension: (id) sender {
    if( newProj == nil ) {
        newProj = [[IFNewProject alloc] init];
    }
    [newProj createInform7Extension];
}

- (IBAction) newInform6Project: (id) sender {
    if( newProj == nil ) {
        newProj = [[IFNewProject alloc] init];
    }
    [newProj createInform6Project];
}

- (IBAction) showInspectors: (id) sender {
	[[IFInspectorWindow sharedInspectorWindow] showWindow: self];
}

- (BOOL)validateMenuItem:(NSMenuItem*) menuItem {
	SEL itemSelector = [menuItem action];
    // Only allow showing the inspectors if it's currently hidden, and it's not an Inform7 project active.
	if (itemSelector == @selector(showInspectors:)) {
		return [[IFInspectorWindow sharedInspectorWindow] isHidden] &&
               ![[IFInspectorWindow sharedInspectorWindow] isInform7ProjectActive];
	}

	// Spell checking
	if (itemSelector == @selector(toggleSourceSpellChecking:)) {
		[menuItem setState: [self sourceSpellChecking] ? NSOnState : NSOffState];
		return YES;
	}

	return YES;
}

// = Menu actions =

- (void) visitWebsite: (id) sender {
	// Get the URL
	NSURL* websiteUrl = [NSURL URLWithString: @"http://www.inform7.com"];
	
	// Visit it
	[[NSWorkspace sharedWorkspace] openURL: websiteUrl];
}

- (void) showWelcome: (id) sender {
    // Toggle welcome window
    if( [[[IFWelcomeWindow sharedWelcomeWindow] window] isVisible] ) {
        [IFWelcomeWindow hideWelcomeWindow];
    } else {
        [IFWelcomeWindow showWelcomeWindow];
    }
}

// Construct an attributed string containing the extension name and version in the menu
-(NSAttributedString*) attributedStringForExtensionInfo: (IFExtensionInfo*) info
                                           withTabWidth: (float) tabWidth
                                               widthOut: (float*) widthOut {
    NSFont* systemFont       = [NSFont menuFontOfSize: 14];
    NSFont* smallFont        = [NSFont menuFontOfSize: [systemFont pointSize] - 4];

    // NSParagraphStyleAttributeName
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    NSTextTab* tab = [[NSTextTab alloc] initWithType: NSLeftTabStopType
                                            location: tabWidth];
    paragraph.tabStops = @[tab];
    paragraph.lineBreakMode = NSLineBreakByClipping;

    NSDictionary* greyDictionary  = @{NSForegroundColorAttributeName: [NSColor grayColor],
                                                 NSFontAttributeName: systemFont,
                                       NSParagraphStyleAttributeName: paragraph};
    NSDictionary* smallBlackDictionary = @{NSForegroundColorAttributeName: [NSColor blackColor],
                                                      NSFontAttributeName: smallFont,
                                            NSParagraphStyleAttributeName: paragraph};
    NSDictionary* smallGreyDictionary = @{NSForegroundColorAttributeName: [NSColor grayColor],
                                                     NSFontAttributeName: smallFont,
                                           NSParagraphStyleAttributeName: paragraph};
    NSDictionary* blackDictionary = @{NSForegroundColorAttributeName: [NSColor blackColor],
                                                 NSFontAttributeName: systemFont,
                                       NSParagraphStyleAttributeName: paragraph};
    NSDictionary* dict;

    if (info.isBuiltIn) {
        dict = greyDictionary;
    } else {
        dict = blackDictionary;
    }

    NSMutableAttributedString* attributedTitle = [[NSMutableAttributedString alloc] initWithString: info.displayName
                                                                                        attributes: dict];
    if( widthOut ) {
        *widthOut = [attributedTitle size].width;
    }

    // Append version string if we have one
    if( info.version != nil ) {
        if (info.isBuiltIn) {
            dict = smallGreyDictionary;
        } else {
            dict = smallBlackDictionary;
        }
        NSString* version = [NSString stringWithFormat:@"\t%@", info.version];
        NSAttributedString* attributedVersion = [[NSAttributedString alloc] initWithString: version
                                                                                 attributes: dict];
        [attributedTitle appendAttributedString: attributedVersion];
    }

    return attributedTitle;
}

// = The extensions menu =

- (void) updateExtensionsMenu {
	IFExtensionsManager* mgr = [IFExtensionsManager sharedNaturalInformExtensionsManager];

	// Clear out the menus
    [[openExtensionMenu submenu] removeAllItems];
    [[newExtensionProjectMenu submenu] removeAllItems];

    // Add new Extension items
    NSMenuItem* newExtensionItem = [[NSMenuItem alloc] init];
    [newExtensionItem setTitle: [IFUtility localizedString: @"New Extension..."]];
    [newExtensionItem setTarget: self];
    [newExtensionItem setTag:    -1];
    [newExtensionItem setAction: @selector(newExtensionProject:)];
    [[newExtensionProjectMenu submenu] addItem: newExtensionItem];

    NSMenu* newMenu = [[NSMenu alloc] init];
    [newMenu setTitle: [IFUtility localizedString:@"Create From Installed Extension"]];
    NSMenuItem* newMenuItem = [[NSMenuItem alloc] init];
    [newMenuItem setTitle: [newMenu title]];
    [newMenuItem setSubmenu: newMenu];
    [[newExtensionProjectMenu submenu] addItem: newMenuItem];

	// Clear out the list of extension tags
	extensionSources = [[NSMutableArray alloc] init];

	// Generate the extensions menu
    for( NSString* author in [mgr availableAuthors] ) {
        // Find the maximum width of all extensions by this author
        float maxWidth = 0.0f;
        for( IFExtensionInfo* info in [mgr availableExtensionsByAuthor: author] ) {
            float width;
            [self attributedStringForExtensionInfo: info
                                      withTabWidth: 0.0f
                                          widthOut: &width ];
            maxWidth = MAX(maxWidth, width);
        }
        float tabWidth = pixelWidthBetweenExtensionNameAndVersion + maxWidth;

        // Create menu and menu item for the 'Open Installed Extension' menu
        NSMenu* openAuthorMenu = [[NSMenu alloc] init];
        [openAuthorMenu setTitle: author];

        NSMenuItem* openAuthorItem = [[NSMenuItem alloc] init];
        [openAuthorItem setTitle: author];
        [openAuthorItem setSubmenu: openAuthorMenu];
        
        // Create menu and menu item for the 'New Extension Project' menu
        NSMenu* newExAuthorMenu = [[NSMenu alloc] init];
        [newExAuthorMenu setTitle: author];

        NSMenuItem* newExAuthorItem = [[NSMenuItem alloc] init];
        [newExAuthorItem setTitle: author];
        [newExAuthorItem setSubmenu: newExAuthorMenu];

        for( IFExtensionInfo* info in [mgr availableExtensionsByAuthor: author] ) {
            NSAttributedString* attributedTitle = [self attributedStringForExtensionInfo: info
                                                                            withTabWidth: tabWidth
                                                                                widthOut: nil ];

            // Create menu for each extension, for the 'Open Installed Extension' menu
            {
                NSMenuItem* openItem = [[NSMenuItem alloc] init];
                [openItem setAttributedTitle: attributedTitle];
                [openItem setTarget: self];
                [openItem setTag:    [extensionSources count]];
                [openItem setAction: @selector(openExtension:)];
                
                [openAuthorMenu addItem: openItem];
            }

            // Create menu for each extension, for the 'New Extension Project' menu
            {
                NSMenuItem* newExItem = [[NSMenuItem alloc] init];
                [newExItem setAttributedTitle: attributedTitle];
                [newExItem setTarget: self];
                [newExItem setTag:    [extensionSources count]];
                [newExItem setAction: @selector(newExtensionProject:)];

                [newExAuthorMenu addItem: newExItem];
            }


            // Add an entry in the extensionSources array so we know which file this refers to
            [extensionSources addObject: info.filepath];
        }
        [[openExtensionMenu submenu] addItem: openAuthorItem];
        [newMenu addItem: newExAuthorItem];
	}
}

- (void) openExtension: (id) sender {
	// Get the tag, and from that, get the source file we want to open
	NSInteger tag = [sender tag];
	NSString* sourceFilename = extensionSources[tag];
	
	// Open the file
    NSError* error;
	NSDocument* newDoc = [[IFSingleFile alloc] initWithContentsOfURL: [NSURL fileURLWithPath:sourceFilename]
															  ofType: @"Inform 7 extension"
                                                               error: &error];
	
	[[NSDocumentController sharedDocumentController] addDocument: newDoc];
	[newDoc makeWindowControllers];
	[newDoc showWindows];	
}

- (void) newExtensionProject: (id) sender {
    // Get the tag, and from that, get the source file we want
    NSInteger tag = [sender tag];

    if( newProj == nil ) {
        newProj = [[IFNewProject alloc] init];
    }

    if( tag >= 0 )
    {
        NSString*   sourceFilename  = extensionSources[tag];
        NSString*   projectTitle    = [[sourceFilename lastPathComponent] stringByDeletingPathExtension];
        NSURL*      projectURL      = [NSURL fileURLWithPath:sourceFilename];

        [newProj createInform7ExtensionProject: projectTitle
                              fromExtensionURL: projectURL];
    }
    else
    {
        [newProj createInform7Project: nil
                             fileType: IFFileTypeInform7ExtensionProject
                                story: nil];
    }
}

// = Some misc actions =

- (IBAction) showPreferences: (id) sender {
#if defined(DEBUG_EXPORT_HELP_IMAGES)
    [IFSkeinItemView exportHelpImages];
#endif // defined(DEBUG_EXPORT_HELP_IMAGES)

	[[IFPreferenceController sharedPreferenceController] showWindow: self];
}

// = The help menu =

- (IBAction) docIndex: (id) sender {
    // If we can switch to an open project document, do so
    for(NSDocument* doc in [[NSDocumentController sharedDocumentController] documents]) {
        if( [doc isKindOfClass: [IFProject class]] ) {
            // Bring to front
            for(NSWindowController* controller in [doc windowControllers]) {
                [[controller window] makeKeyAndOrderFront: self];
                if([controller isKindOfClass: [IFProjectController class]]) {
                    IFProjectController* pc = (IFProjectController*) controller;
                    [pc docIndex: sender];
                }
            }
            
            return;
        }
    }

    // This is called if there is no project currently open: in this case, the help isn't really available as
    // it's dependent on the project window.
    [IFUtility runAlertWarningWindow: nil
                               title: @"Help not yet available"
                             message: @"Help not available description"];
}

- (IBAction) showExtensionsFolder: (id) sender {
    NSString* externalExtensions = [IFUtility pathForInformExternalExtensions];
    [[NSWorkspace sharedWorkspace] openFile: externalExtensions];
}

// = Installing extensions =

- (IBAction) installExtension: (id) sender {
	// Present a panel for adding new extensions
	NSOpenPanel* panel;
	if (!openExtensionPanel) {
		openExtensionPanel = [NSOpenPanel openPanel];
	}
	panel = openExtensionPanel;

	[panel setAccessoryView: nil];
	[panel setCanChooseFiles: YES];
	[panel setCanChooseDirectories: NO];
	[panel setResolvesAliases: YES];
	[panel setAllowsMultipleSelection: YES];
	[panel setTitle: [IFUtility localizedString:@"Install Inform 7 Extension"]];
	[panel setDelegate: [IFExtensionsManager sharedNaturalInformExtensionsManager]];    // Extensions manager determines which file types are valid to choose (panel:shouldShowFilename:)

    [panel beginWithCompletionHandler:^(NSInteger result)
     {
         [panel setDelegate: nil];

         if (result != NSOKButton) return;

         // Just add the extension
         // Add the files
         BOOL succeeded = YES;
         for(NSURL* file in [panel URLs]) {
             succeeded = [[IFExtensionsManager sharedNaturalInformExtensionsManager] installExtension: [file path]
                                                                                            finalPath: nil
                                                                                                title: nil
                                                                                               author: nil
                                                                                              version: nil
                                                                                   showWarningPrompts: YES
                                                                                               notify: NO];
             if (!succeeded) break;
         }

         // Re-run the census. In particular, this will update the Public Library of extensions web page if visible
         [[IFExtensionsManager sharedNaturalInformExtensionsManager] startCensus: @YES];

         // Report an error if we couldn't install the extension for some reason
         if (!succeeded) {
             // Display a 'failed to add extension' alert sheet
             [IFUtility runAlertWarningWindow: nil
                                        title: @"Failed to Install Extension"
                                      message: @"Failed to Install Extension Explanation"];
         }
     }];
}

// = Searching =

- (IBAction) showFind2: (id) sender {
	[[IFFindController sharedFindController] showWindow: self];
}

- (IBAction) findNext: (id) sender {
	[[IFFindController sharedFindController] findNext: self];
}

- (IBAction) findPrevious: (id) sender {
	[[IFFindController sharedFindController] findPrevious: self];
}

- (IBAction) useSelectionForFind: (id) sender {
	[[IFFindController sharedFindController] useSelectionForFind: self];
}

// = Termination =

- (void) applicationWillTerminate: (NSNotification*) not {
    newProj = nil;

    //
    // Clean up preference panes
    //
    [[IFPreferenceController sharedPreferenceController] removeAllPreferencePanes];
    
    [IFImageCache dealloc];
}

- (NSMenuItem*) debugMenu {
	return debugMenu;
}

- (BOOL) sourceSpellChecking {
    return [[NSUserDefaults standardUserDefaults] boolForKey: IFSourceSpellChecking];
}

- (IBAction) toggleSourceSpellChecking: (id) sender {
	// Toggle the setting
	BOOL sourceSpellChecking = ![[NSUserDefaults standardUserDefaults] boolForKey: IFSourceSpellChecking];
	
    // Tell each document's controller about the change
    for(NSDocument* doc in [[NSDocumentController sharedDocumentController] documents]) {
        for(NSWindowController* controller in [doc windowControllers]) {
            if([controller isKindOfClass: [IFProjectController class]]) {
                IFProjectController* pc = (IFProjectController*) controller;
                [pc setSourceSpellChecking: sourceSpellChecking];
            }
            else if([controller isKindOfClass: [IFSingleController class]]) {
                IFSingleController* sc = (IFSingleController*) controller;
                [sc setSourceSpellChecking: sourceSpellChecking];
            }
        }
    }

	// Store the result
	[[NSUserDefaults standardUserDefaults] setBool: sourceSpellChecking
											forKey: IFSourceSpellChecking];
}

- (BOOL) copyResource: (NSString*) resource
          toDirectory: (NSString*) destDir
                error: (NSError*__autoreleasing*) error {
    NSString* extension = [resource pathExtension];
    NSString* name = [[resource lastPathComponent] stringByDeletingPathExtension];

    fileCopyDestination = [[destDir stringByAppendingPathComponent: name]
                             stringByAppendingPathExtension: extension];
    fileCopySource = [[NSBundle mainBundle] pathForResource: name ofType: extension];

    if( fileCopySource == nil ) {
        [IFUtility runAlertWarningWindow: nil
                                   title: @"Export failed"
                                 message: [IFUtility localizedString:@"Export of %@ failed - could not find source."], fileCopySource];
        return NO;
    }

    if( [[NSFileManager defaultManager] fileExistsAtPath: fileCopyDestination] ) {
        NSString* confirm = [NSString stringWithFormat: [IFUtility localizedString: @"Are you sure you want to overwrite file '%@'?"], [fileCopyDestination lastPathComponent]];

        [IFUtility runAlertYesNoWindow: nil
                                 title: [IFUtility localizedString: @"Are you sure?"]
                                   yes: [IFUtility localizedString: @"Overwrite"]
                                    no: [IFUtility localizedString: @"Cancel"]
                         modalDelegate: self
                        didEndSelector: @selector(confirmFileCopyDidEnd:returnCode:contextInfo:)
                           contextInfo: nil
                               message: confirm];
        return NO;
    }

    BOOL result = [self copyResourceWithoutConfirmation: fileCopySource
                                          toDestination: fileCopyDestination
                                                  error: error];
    fileCopySource = nil;
    fileCopyDestination = nil;

    if( !result ) {
        return NO;
    }
    
    return YES;
}

- (BOOL) copyResourceWithoutConfirmation: (NSString*) source
                           toDestination: (NSString*) destination
                                   error: (NSError*__autoreleasing*) error {
    // Remove any existing file at destination
    [[NSFileManager defaultManager] removeItemAtPath: destination
                                               error: error];

    if ( ![[NSFileManager defaultManager] copyItemAtPath: source
                                                  toPath: destination
                                                   error: error]) {
        [IFUtility runAlertWarningWindow: nil
                                   title: @"Export failed"
                                 message: [IFUtility localizedString:@"Export to %@ failed - error code %x"], destination, [*error localizedDescription]];
        return NO;
    }
    return YES;
}

- (void) confirmFileCopyDidEnd: (NSWindow *) sheet
                    returnCode: (int) returnCode
                   contextInfo: (void *) contextInfo {
    NSString* sourceCopy = [fileCopySource copy];
    NSString* destCopy   = [fileCopyDestination copy];
    
    fileCopySource = nil;
    fileCopyDestination = nil;

	if (returnCode == NSAlertFirstButtonReturn) {
        NSError* error;
        if( [self copyResourceWithoutConfirmation: sourceCopy
                                    toDestination: destCopy
                                            error: &error] ) {
            exportToEPubIndex++;
            [self exportNext:[destCopy stringByDeletingLastPathComponent]];
        }
	}
}

- (void) exportNext: (NSString*) destDir {
    NSArray*  exportFiles = @[@"Inform - A Design System for Interactive Fiction.epub",
                              @"Changes to Inform.epub"];

    NSError* error = nil;

    for(; exportToEPubIndex < [exportFiles count]; exportToEPubIndex++) {
        if (![self copyResource: exportFiles[exportToEPubIndex]
                    toDirectory: destDir
                          error: &error]) {
            // Something stopped the flow - an error or a confirmation dialog.
            return;
        }
    }

    // All went well, open directory in Finder...
    [[NSWorkspace sharedWorkspace] openFile: destDir];
}

- (IBAction) exportToEPub: (id) sender {
    NSOpenPanel * exportPanel = [NSOpenPanel openPanel];
    [exportPanel setCanChooseFiles:NO];
    [exportPanel setCanChooseDirectories:YES];
    [exportPanel setCanCreateDirectories:YES];
    [exportPanel setAllowsMultipleSelection:NO];
	[exportPanel setTitle: [IFUtility localizedString:@"Choose a directory to export into"]];
    [exportPanel setPrompt: [IFUtility localizedString:@"Choose Directory"]];

    NSWindow* window = nil;
    if( [[[IFWelcomeWindow sharedWelcomeWindow] window] isVisible] ) {
        window = [[IFWelcomeWindow sharedWelcomeWindow] window];
    }
    
    [exportPanel beginSheetModalForWindow:window completionHandler:^(NSInteger result)
     {
         if (result == NSOKButton) {
             self->exportToEPubIndex = 0;
             [self exportNext: [[exportPanel URL] path]];
         }
     }];
}

@end
