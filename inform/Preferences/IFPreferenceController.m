//
//  IFPreferenceController.m
//  Inform
//
//  Created by Andrew Hunter on 12/01/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import "IFPreferenceController.h"
#import "IFPreferences.h"
#import "IFUtility.h"
#import "IFPreferencePane.h"

@implementation IFPreferenceController {
    // The toolbar
    NSToolbar* preferenceToolbar;					// Contains the list of settings panes
    NSMutableArray* preferenceViews;				// The settings panes themselves
    NSMutableDictionary* toolbarItems;				// The toolbar items
}

// = Construction =

+ (IFPreferenceController*) sharedPreferenceController {
	static IFPreferenceController* sharedPrefController = nil;

	if (sharedPrefController == nil) {
		sharedPrefController = [[IFPreferenceController alloc] init];
	}
	
	return sharedPrefController;
}

// = Initialisation =

- (instancetype) init {
	NSRect mainScreenRect = [[NSScreen mainScreen] frame];
	
	self = [super initWithWindow: [[NSWindow alloc] initWithContentRect: NSMakeRect(NSMinX(mainScreenRect)+200, NSMaxY(mainScreenRect)-400, 512, 300) 
															   styleMask: NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable
																 backing: NSBackingStoreBuffered 
																   defer: YES]];
	
	if (self) {
		// Set up window
		[self setWindowFrameAutosaveName: @"PreferenceWindow"];
		[[self window] setDelegate: self];
		[[self window] setTitle: [IFUtility localizedString: @"Inform Preferences"]];
				
		// Set up preference toolbar
		toolbarItems = [[NSMutableDictionary alloc] init];
		
		// Set up preference views
		preferenceViews = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (IBAction) showWindow: (id) sender {
	// Set up the toolbar while showing the window
	if (preferenceToolbar == nil) {
		preferenceToolbar = [[NSToolbar alloc] initWithIdentifier: @"PreferenceWindowToolbarMk2"];

		[preferenceToolbar setAllowsUserCustomization: NO];
		[preferenceToolbar setAutosavesConfiguration: NO];

		[preferenceToolbar setDelegate: self];
		[preferenceToolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
		[[self window] setToolbar: preferenceToolbar];
		[preferenceToolbar setVisible: YES];

		[self switchToPreferencePane: [preferenceViews[0] identifier]];
	}

    // Set the window frame based on stored coordinates
    NSPoint topLeft = [[IFPreferences sharedPreferences] preferencesTopLeftPosition];
    topLeft.y = [[NSScreen screens][0] frame].size.height - topLeft.y;
    NSRect rect = [[self window] frame];
    rect.origin.x = topLeft.x;
    rect.origin.y = topLeft.y - rect.size.height;
    
    [[self window] setFrame: rect display:YES];

    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(preferencesWillClose:)
                                                 name: NSWindowWillCloseNotification
                                               object: nil];
	[super showWindow: sender];
}

-(void) preferencesWillClose:(NSNotification*) notification {
    NSWindow *windowAboutToClose = [notification object];
    if( [self window] == windowAboutToClose ) {

        // Save the position of the top left corner of window
        NSPoint topLeft;
        NSRect rect = [[self window] frame];
        topLeft.x = rect.origin.x;
        topLeft.y = rect.origin.y + rect.size.height;
        topLeft.y = [[NSScreen screens][0] frame].size.height - topLeft.y;
        [[IFPreferences sharedPreferences] setPreferencesTopLeftPosition: topLeft];
        
        // Remove notifier
        [[NSNotificationCenter defaultCenter] removeObserver: self];

        // Remove any open color panel
        if([NSColorPanel sharedColorPanelExists]) {
            [[NSColorPanel sharedColorPanel] close];
        }
    }
}

// = Adding new preference views =

- (void) addPreferencePane: (IFPreferencePane*) newPane {
	// Add to the list of preferences view
	[preferenceViews addObject: newPane];
	
	// Add to the toolbar
	NSToolbarItem* newItem = [[NSToolbarItem alloc] initWithItemIdentifier: [newPane identifier]];
	
	[newItem setAction: @selector(switchPrefPane:)];
	[newItem setTarget: self];
	[newItem setImage: [newPane toolbarImage]];
	[newItem setLabel: [newPane preferenceName]];
	[newItem setToolTip: [newPane tooltip]];
	
	toolbarItems[[newPane identifier]] = newItem;

}

-(void) removeAllPreferencePanes {
	 preferenceToolbar = nil;
	 preferenceViews = nil;
	 toolbarItems = nil;
}

// = Toolbar delegate =

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray* result = [NSMutableArray array];

	for( IFPreferencePane* toolId in preferenceViews ) {
		[result addObject: [toolId identifier]];
	}
		
	return result;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
	NSMutableArray* res = (NSMutableArray*)[self toolbarAllowedItemIdentifiers: toolbar];
	
	[res addObject: NSToolbarFlexibleSpaceItemIdentifier];
	
	return res;
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [self toolbarAllowedItemIdentifiers: toolbar];
}

- (NSToolbarItem *)toolbar: (NSToolbar*) toolbar 
	 itemForItemIdentifier: (NSString*) itemIdentifier 
 willBeInsertedIntoToolbar: (BOOL)flag {
	return toolbarItems[itemIdentifier];
}

// = Preference switching =

- (IFPreferencePane*) preferencePane: (NSString*) paneIdentifier {
	for( IFPreferencePane* toolId in preferenceViews ) {
		if ([[toolId identifier] isEqualToString: paneIdentifier]) {
			return toolId;
        }
	}

	return nil;
}

- (void) switchToPreferencePane: (NSString*) paneIdentifier {
	// Find the preference view that we're using
	IFPreferencePane* toolId = nil;
	
	for( IFPreferencePane* possibleToolId in preferenceViews ) {
		if ([[possibleToolId identifier] isEqualToString: paneIdentifier]) {
            toolId = possibleToolId;
			break;
        }
	}
	
	// Switch to that view
	if (toolId) {
		NSView* preferencePane = [toolId preferenceView];
		
		if ([[self window] contentView] == preferencePane) return;
		
		if ([preferenceToolbar respondsToSelector: @selector(setSelectedItemIdentifier:)]) {
			[preferenceToolbar setSelectedItemIdentifier: paneIdentifier];
		}
		
		NSRect currentFrame = [[[self window] contentView] frame];
		NSRect oldFrame = currentFrame;
		NSRect windowFrame = [[self window] frame];
		
		currentFrame.origin.y    -= [preferencePane frame].size.height - currentFrame.size.height;
		currentFrame.size.height  = [preferencePane frame].size.height;
		
		// Grr, complicated, as OS X provides no way to work out toolbar proportions except in 10.3
		windowFrame.origin.x    += (currentFrame.origin.x - oldFrame.origin.x);
		windowFrame.origin.y    += (currentFrame.origin.y - oldFrame.origin.y);
		windowFrame.size.width  += (currentFrame.size.width - oldFrame.size.width);
		windowFrame.size.height += (currentFrame.size.height - oldFrame.size.height);
		
		[[self window] setContentView: [[NSView alloc] init]];
		[[self window] setFrame: windowFrame
						display: YES
						animate: YES];
		[[self window] setContentView: preferencePane];
	}
}

- (void) switchPrefPane: (id) sender {
	[self switchToPreferencePane: [(NSToolbarItem*)sender itemIdentifier]];
}

@end
