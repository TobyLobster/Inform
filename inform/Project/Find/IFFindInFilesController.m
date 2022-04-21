//
//  IFFindInFilesController.m
//  Inform
//
//  Created by Toby Nelson in 2014.
//

#import "IFFindInFilesController.h"
#import "IFAppDelegate.h"
#import "IFFindResult.h"
#import "IFFindInFiles.h"
#import "IFProjectController.h"
#import "IFComboBox.h"
#import "IFUtility.h"

static NSString* const IFFindHistoryPref		= @"IFFindHistory";
static NSString* const IFReplaceHistoryPref	    = @"IFReplaceHistory";

static const int FIND_HISTORY_LENGTH = 30;

@implementation IFFindInFilesController {
    // The components of the find dialog
    IBOutlet NSComboBox*	findPhrase;									// The phrase to search for
    IBOutlet NSComboBox*	replacePhrase;								// The phrase to replace it with

    // Ignore case radio button
    IBOutlet NSButton*		ignoreCase;									// The 'ignore case' checkbox

    // Where to search
    IBOutlet NSButton*		findInSource;                               // The 'Source' checkbox
    IBOutlet NSButton*		findInExtensions;                           // The 'Extensions' checkbox
    IBOutlet NSButton*		findInDocumentationBasic;                   // The 'Documentation Basic' checkbox
    IBOutlet NSButton*		findInDocumentationSource;                  // The 'Documentation Source' checkbox
    IBOutlet NSButton*		findInDocumentationDefinitions;             // The 'Documentation Definitions' checkbox

    // Pull down menu of how to search
    IBOutlet NSPopUpButton* searchType;									// The 'contains/begins with/complete word/regexp' pop-up button
    IBOutlet NSMenuItem*	containsItem;								// Choices for the type of object to find
    IBOutlet NSMenuItem*	beginsWithItem;
    IBOutlet NSMenuItem*	completeWordItem;
    IBOutlet NSMenuItem*	regexpItem;

    // Buttons
    IBOutlet NSButton*		findAll;
    IBOutlet NSButton*		replaceAll;

    // Progress
    IBOutlet NSProgressIndicator* findProgress;							// The 'searching' progress indicator

    // Parent view to position extra content
    IBOutlet NSView*		auxViewPanel;								// The auxilary view panel
    IBOutlet NSWindow*      findInFilesWindow;

    // The regular expression help view
    IBOutlet NSView*		regexpHelpView;								// The view containing information about regexps

    // The 'find all' views
    IBOutlet NSView*		foundNothingView;							// The view to show if we don't find any matches
    IBOutlet NSView*		findAllView;								// The main 'find all' view
    IBOutlet NSTableView*	findAllTable;								// The 'find all' results table
    IBOutlet NSTextField*   findCountText;                              // The text count of how many results we have found

    // Things we've searched for
    NSMutableArray*			replaceHistory;								// The 'replace' history
    NSMutableArray*			findHistory;								// The 'find' history

    BOOL					searching;									// YES if we're searching for results
    NSArray*                findAllResults;								// The 'find all' results view
    int						findAllCount;								// Used to generate the identifier
    id						findIdentifier;								// The current find all identifier
    CGFloat                 borders;

    // Auxiliary views
    NSView*                 auxView;									// The auxiliary view that is being displayed
    NSRect                  winFrame;									// The default window frame

    // Project we are going to search
    IFProject*                  project;                                // Project to search in
    IFProjectController*        controller;                             // Project controller to use
    IFFindInFiles*              findInFiles;                            // Object used to perform searching
    
    // The delegate
    /// The delegate that we've chosen to work with
    __weak id<IFFindInFilesDelegate> activeDelegate;
}


#pragma mark - Initialisation

+ (IFFindInFilesController*) sharedFindInFilesController {
	static IFFindInFilesController* sharedController = nil;
	
	if (!sharedController) {
		sharedController = [[IFFindInFilesController alloc] initWithWindowNibName: @"FindInFiles"];
	}
	
	return sharedController;
}

- (instancetype) initWithWindowNibName: (NSString*) nibName {
	self = [super initWithWindowNibName: (NSString*) nibName];
	
	if (self) {
		// Get the find/replace history
		findHistory = [[[NSUserDefaults standardUserDefaults] objectForKey: IFFindHistoryPref] mutableCopy];
		replaceHistory = [[[NSUserDefaults standardUserDefaults] objectForKey: IFReplaceHistoryPref] mutableCopy];
		
		if (!findHistory)		findHistory		= [[NSMutableArray alloc] init];
		if (!replaceHistory)	replaceHistory	= [[NSMutableArray alloc] init];
        
        findInFiles = [[IFFindInFiles alloc] init];

        // Get notified when the window is closing...
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowWillClose:)
                                                     name:NSWindowWillCloseNotification
                                                   object:nil];
        
    }
	
	return self;
}

- (void) dealloc {
	// Stop receiving notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Updating the history

- (void) addPhraseToFindHistory: (NSString*) phrase {
	phrase = [phrase copy];
	
	// Ensure that we don't store a duplicate copy of the phrase
	NSUInteger lastIndex = [findHistory indexOfObject: phrase];
	if (lastIndex != NSNotFound) {
		[findHistory removeObjectAtIndex: lastIndex];
	}
	
	// Insert the new phrase into the find history
	[findHistory insertObject: phrase
					  atIndex: 0];
	
	// Ensure that we limit the number of items in the history
	while ([findHistory count] > FIND_HISTORY_LENGTH) {
		[findHistory removeLastObject];
	}
	
	// Store in the user defaults
	[[NSUserDefaults standardUserDefaults] setObject: [findHistory copy]
											  forKey: IFFindHistoryPref];
	
	// Update the combo box
	[findPhrase reloadData];
}

- (void) addPhraseToReplaceHistory: (NSString*) phrase {
	phrase = [phrase copy];
	
	// Ensure that we don't store a duplicate copy of the phrase
	NSUInteger lastIndex = [replaceHistory indexOfObject: phrase];
	if (lastIndex != NSNotFound) {
		[replaceHistory removeObjectAtIndex: lastIndex];
	}
	
	// Insert the new phrase into the find history
	[replaceHistory insertObject: phrase
						 atIndex: 0];
	
	// Ensure that we limit the number of items in the history
	while ([replaceHistory count] > FIND_HISTORY_LENGTH) {
		[replaceHistory removeLastObject];
	}
	
	// Store in the user defaults
	[[NSUserDefaults standardUserDefaults] setObject: [replaceHistory copy]
											  forKey: IFReplaceHistoryPref];
	
	// Update the combo box
	[replacePhrase reloadData];
}

#pragma mark - Actions

- (IFFindType) currentFindType {
	NSMenuItem* selected = [searchType selectedItem];
	
	IFFindType flags = IFFindInvalidType;
	if ([ignoreCase state] == NSControlStateValueOn) flags |= IFFindCaseInsensitive;
	
	if (selected == containsItem) {
		return IFFindContains | flags;
	} else if (selected == beginsWithItem) {
		return IFFindBeginsWith | flags;
	} else if (selected == completeWordItem) {
		return IFFindCompleteWord | flags;
	} else if (selected == regexpItem) {
		return IFFindRegexp | flags;
	} else {
		return IFFindContains | flags;
	}
}

- (IFFindLocation) currentFindLocation {
    IFFindLocation locations = IFFindNowhere;
    if( [findInSource state] == NSControlStateValueOn )                   locations |= IFFindSource;
    if( [findInExtensions state] == NSControlStateValueOn )               locations |= IFFindExtensions;
    if( [findInDocumentationBasic state] == NSControlStateValueOn )       locations |= IFFindDocumentationBasic;
    if( [findInDocumentationSource state] == NSControlStateValueOn )      locations |= IFFindDocumentationSource;
    if( [findInDocumentationDefinitions state] == NSControlStateValueOn ) locations |= IFFindDocumentationDefinitions;
    return locations;
}

-(NSString*) locationNameFromResult:(IFFindResult*) findResult {
    NSString* locationTypeKey = nil;
    
    switch( [findResult locationType] ) {
        case IFFindCurrentPage:
            locationTypeKey = @"LocationCurrentPage";
            break;
        case IFFindSource:
            locationTypeKey = @"LocationSource";
            break;
        case IFFindExtensions:
            locationTypeKey = @"LocationExtensions";
            break;
        case IFFindDocumentationSource:
        case IFFindDocumentationDefinitions:
        case IFFindDocumentationBasic:
            if( [findResult isRecipeBookResult] ) {
                locationTypeKey = @"LocationDocumentationRecipeBook";
            }
            else {
                locationTypeKey = @"LocationDocumentationWritingWithInform";
            }
            break;
        default:
            NSAssert(false, @"Could not find location name for location %d", (int) [findResult locationType]);
            return @"?";
    }

    return [IFUtility localizedString: locationTypeKey];
}

- (IBAction) findTypeChanged: (id) sender {
	if ([searchType selectedItem] == regexpItem) {
		[self showAuxiliaryView: regexpHelpView];
	} else {
		if (auxView == regexpHelpView) {
			[self showAuxiliaryView: nil];
		}
	}
}

- (void) updateControls {
    BOOL hasSearchTerm = [[findPhrase stringValue] length] > 0;

    // Enable or disable the buttons
	[replaceAll setEnabled: hasSearchTerm];
	[findAll    setEnabled: hasSearchTerm];

	// 'Contains' is the basic type of search
	if (![[searchType selectedItem] isEnabled]) {
		[searchType selectItem: containsItem];
	}
}

- (void) windowDidLoad {
	[self updateControls];
	
    // Restore frame position
    [[self window] setFrameUsingName:@"FindInFilesFrame"];

	winFrame		= [[self window] frame];
    borders         = self.window.frame.size.height + findAllView.frame.size.height - findAllTable.frame.size.height;

    [findProgress setHidden: YES];
}

- (void) showWindow:(id)sender {
	// Standard behaviour
	[super showWindow: sender];

	// Set the first responder
	[[self window] makeFirstResponder: findPhrase];
}

- (void) resizeToFitResults {
    // Calculate new height of table based on the number of results we have.
    CGFloat newTableHeight = MIN(20,findAllResults.count) * (findAllTable.rowHeight+findAllTable.intercellSpacing.height);

    NSRect windowFrame = self.window.frame;                     // Get current height of window
    CGFloat newHeight = borders + newTableHeight;               // Calculate new height of window
    CGFloat delta = newHeight - windowFrame.size.height;        // Find out the difference
    windowFrame.origin.y -= delta;                              // Adjust the window origin so the top-left of the window remains in the same place
    windowFrame.size.height = newHeight;                        // Adjust to the new height
    [self.window setFrame:windowFrame display:YES animate:NO];  // Set the window frame
}

- (void) updateFindAllResults {
	// Show nothing if there are no results in the find view
	if ([findAllResults count] <= 0) {
		[self showAuxiliaryView: foundNothingView];
		return;
	}

	// Refresh the table
	[findAllTable reloadData];

    // Disable displaying stuff on screen while we adjust window/view size and positions
    //NSDisableScreenUpdates();

    // Compose the results count message
    NSString* message;
    if( [findAllResults count] == 1 ) {
        message = [IFUtility localizedString: @"Found Result Count"];
    } else {
        message = [IFUtility localizedString: @"Found Results Count"];
        message = [NSString stringWithFormat:message, [findAllResults count]];
    }
    [findCountText setStringValue:message];

    // Show the find all view
	[self showAuxiliaryView: findAllView];
 
    // Resize window to fit the number of results
    [self resizeToFitResults];
    
    // Enable displaying stuff on screen now that we have adjusted window/view size and positions
    //NSEnableScreenUpdates();
}

- (void) setProject: (IFProject*) aProject {
    project = aProject;
}

- (void) setController: (IFProjectController*) aController {
    controller = aController;
}

- (void) showFindInFilesWindow: (IFProjectController*) aController {
    [self setProject: [aController document]];
    [self setController: aController];
	[self showWindow: self];
}

-(void) startFindInFilesSearchWithPhrase: (NSString*) aPhrase
                        withLocationType: (IFFindLocation) aLocationType
                                withType: (IFFindType) aType {
    [findPhrase setStringValue:aPhrase];

    // Set options
    [ignoreCase setState: (aType & IFFindCaseInsensitive) ? NSControlStateValueOn : NSControlStateValueOff];
    switch ( aType ) {
        case IFFindContains:     [searchType selectItem: containsItem]; break;
        case IFFindBeginsWith:   [searchType selectItem: beginsWithItem]; break;
        case IFFindCompleteWord: [searchType selectItem: completeWordItem]; break;
        case IFFindRegexp:       [searchType selectItem: regexpItem]; break;
        default:                 [searchType selectItem: containsItem]; break;
    }

    [findInSource                   setState: (aLocationType & IFFindSource)                   ? NSControlStateValueOn : NSControlStateValueOff];
    [findInExtensions               setState: (aLocationType & IFFindExtensions)               ? NSControlStateValueOn : NSControlStateValueOff];
    [findInDocumentationBasic       setState: (aLocationType & IFFindDocumentationBasic)       ? NSControlStateValueOn : NSControlStateValueOff];
    [findInDocumentationSource      setState: (aLocationType & IFFindDocumentationSource)      ? NSControlStateValueOn : NSControlStateValueOff];
    [findInDocumentationDefinitions setState: (aLocationType & IFFindDocumentationDefinitions) ? NSControlStateValueOn : NSControlStateValueOff];

    [self findTypeChanged: self];
    [self updateControls];

    // Start the find in files
    [self findAll: self];
}


- (IBAction) findAll: (id) sender {
	// Add the find phrase to the history
	[self addPhraseToFindHistory: [findPhrase stringValue]];

	// Create a new find identifier
	findAllCount++;
	findIdentifier = @(findAllCount);

	// Clear out the find results
	findAllResults = nil;
    [findAllTable reloadData];

	// Show progress
    [findProgress setHidden: NO];
    [findProgress setDisplayedWhenStopped: NO];
    [findProgress setMinValue: 0.0f];
    [findProgress setMaxValue: 1.0f];
    [findProgress startAnimation: sender];

	// Start the find
    IFFindLocation locations = [self currentFindLocation];

	[findInFiles startFindInFilesWithPhrase: [findPhrase stringValue]
                             withSearchType: [self currentFindType]
                                fromProject: project
                              withLocations: locations
                          withProgressBlock: ^void(int num, int total, int found)
        {
            // Update progress
            CGFloat progress = (CGFloat) num / (CGFloat) total;
            [self->findProgress setDoubleValue: progress];

            @synchronized([self->findInFiles searchResultsLock])
            {
                // Update results
                if( [self->findInFiles resultsCount] != [self->findAllResults count] ) {
                    NSArray* results = [self->findInFiles results];
                    self->findAllResults = results;
                    [self updateFindAllResults];
                }

                // Have we finished?
                if( num == total ) {
                    // Stop the progress indicator
                    [self->findProgress stopAnimation: self];
                    [self->findProgress setHidden: YES];
                    
                    // Update the results.
                    [self updateFindAllResults];
                }
            }
        }
    ];
}

#pragma mark - Performing 'replace all'

- (IBAction) replaceAll: (id) sender {
    // TODO!
}


#pragma mark - The find all table

- (int)numberOfRowsInTableView: (NSTableView*) aTableView {
	return (int) [findAllResults count];
}

- (id)				tableView: (NSTableView*) aTableView 
	objectValueForTableColumn: (NSTableColumn*) aTableColumn
					row: (int) rowIndex {
    NSAssert(rowIndex < [findAllResults count], @"Table display error");
    if( rowIndex >= [findAllResults count] ) {
        return nil;
    }
	NSString* ident = [aTableColumn identifier];
	IFFindResult* row = findAllResults[rowIndex];
	
	if ([ident isEqualToString: @"location"]) {
        return [self locationNameFromResult: row];
	} else if ([ident isEqualToString: @"context"]) {
		return [row attributedContext];
	}
	
    NSString* document = [row documentDisplayName];
    if( [document compare:@"story" options:NSCaseInsensitiveSearch] == NSOrderedSame ) {
        document = [IFUtility localizedString: @"Find Results Source Document"
                                      default: @"(Source Text)"];
    }
    return document;
}

- (BOOL)                        tableView: (NSTableView *)tableView
    shouldShowCellExpansionForTableColumn: (NSTableColumn *)tableColumn
                                      row: (NSInteger)row {
    // Turn off expansion tooltips
    return NO;
}

- (void)tableView: (NSTableView *)tableView
  willDisplayCell: (id)cell
   forTableColumn: (NSTableColumn *)tableColumn
              row: (NSInteger)rowIndex {
    NSAssert(rowIndex < [findAllResults count], @"Table display error");
    if( rowIndex >= [findAllResults count] ) {
        return;
    }

    IFFindResult* row = findAllResults[rowIndex];
    if( [row isRecipeBookResult] ) {
        [cell setDrawsBackground: YES];
        NSColor* result = (rowIndex & 1) ? [NSColor colorWithCalibratedRed:1.0f green:1.0f blue:210.0f/255.0f alpha:1.0f] :
                                           [NSColor colorWithCalibratedRed:1.0f green:1.0f blue:224.0f/255.0f alpha:1.0f];
        [cell setBackgroundColor: result];
    }
    else {
        [cell setDrawsBackground: NO];
    }
}

- (void)tableView: (NSTableView *)tableView
      didClickRow: (NSInteger)rowIndex {
	IFFindResult* row = findAllResults[rowIndex];
    
    NSString* anchorTag = @"";
    if( [[row definitionAnchorTag] length] > 0 ) {
        anchorTag = [row definitionAnchorTag];
    } else if ( [[row codeAnchorTag] length] > 0 ) {
        anchorTag = [row codeAnchorTag];
    } else if ( [[row exampleAnchorTag] length] > 0 ) {
        anchorTag = [row exampleAnchorTag];
    }
    
    //NSLog(@"tag is %@", anchorTag);
    [controller searchShowSelectedItemAtLocation: (int) [row fileRange].location
                                          phrase: [row phrase]
                                          inFile: [row filepath]
                                            type: [row locationType]
                                       anchorTag: anchorTag];
}


#pragma mark - Find/replace history

- (id)				 comboBox: (NSComboBox*)	aComboBox
	objectValueForItemAtIndex: (int)			index {
	// Choose the history list that's being displayed in the specified combo box
	NSMutableArray* itemArray = nil;
	if (aComboBox == findPhrase) {
		itemArray = findHistory;
	} else if (aComboBox == replacePhrase) {
		itemArray = replaceHistory;
	}
	
	// Return the item
	if (!itemArray || index < 0 || index >= [itemArray count]) {
		return nil;
	} else {
		return itemArray[index];
	}
}

- (int) numberOfItemsInComboBox: (NSComboBox *)	aComboBox {
	// Choose the history list that's being displayed in the specified combo box
	NSMutableArray* itemArray = nil;
	if (aComboBox == findPhrase) {
		itemArray = findHistory;
	} else if (aComboBox == replacePhrase) {
		itemArray = replaceHistory;
	}
	
	// Return the number of items
	if (!itemArray) {
		return 0;
	} else {
		return (int) [itemArray count];
	}
}

#pragma mark - The auxiliary view

- (void) showAuxiliaryView: (NSView*) newAuxView {
	// Do nothing if the aux view hasn't changed
	if (newAuxView == auxView) return;
	
	// Hide the old auxiliary view
	if (auxView) {
        [auxView removeFromSuperview];
		auxView = nil;
	}

	// Hack: Core animation is rubbish and screws everything up if you try to resize the window immediately after adding a layer to a view
	[[self window] displayIfNeeded];
	
	// Show the new auxiliary view
	NSRect auxFrame		= NSMakeRect(0,0,0,0);
	
	if (newAuxView) {
		// Remember this view
		auxFrame	= [newAuxView frame];
		
		// Set its size
		auxFrame.origin		= NSMakePoint(0, NSMaxY(auxViewPanel.bounds)-auxFrame.size.height);
		auxFrame.size.width = [[[self window] contentView] frame].size.width;
		[newAuxView setFrame: auxFrame];
	}
	
	// Resize the window
	NSRect newWinFrame = [[self window] frame];

    CGFloat heightDiff		= (winFrame.size.height + auxFrame.size.height) - newWinFrame.size.height;
	newWinFrame.size.height += heightDiff;
	newWinFrame.origin.y	-= heightDiff;

    [[self window] setFrame:newWinFrame display:YES];
	
	// Add the new view
	if (newAuxView) {
		auxView		= newAuxView;

		auxFrame.origin		= NSMakePoint(0, NSMaxY(auxViewPanel.bounds)-auxFrame.size.height);
		auxFrame.size.width = [[[self window] contentView] frame].size.width;
		[newAuxView setFrame: auxFrame];

        [newAuxView removeFromSuperview];
        [auxViewPanel addSubview:newAuxView];
	}
}

#pragma mark - Combo box delegate methods

- (void) comboBoxEnterKeyPress: (id) sender {
	if (sender == findPhrase) {
		[self findAll: self];
	}
}

- (void)controlTextDidChange: (NSNotification *)aNotification {
    if( aNotification.object == findPhrase ) {
        [self updateControls];
    }
}

#pragma mark - Window delegate methods
- (void) windowWillClose: (NSNotification*) notification {
    NSWindow *win = [notification object];
    
    if( win == findInFilesWindow ) {
        // Clear the find all results
        findAllResults = nil;
        [self showAuxiliaryView: nil];
        [win saveFrameUsingName:@"FindInFilesFrame"];
    }
}

@end
