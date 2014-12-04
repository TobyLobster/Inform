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

static NSString* IFFindHistoryPref		= @"IFFindHistory";
static NSString* IFReplaceHistoryPref	= @"IFReplaceHistory";

#define FIND_HISTORY_LENGTH 30

@implementation IFFindInFilesController

// = Initialisation =

+ (IFFindInFilesController*) sharedFindInFilesController {
	static IFFindInFilesController* sharedController = nil;
	
	if (!sharedController) {
		sharedController = [[IFFindInFilesController alloc] initWithWindowNibName: @"FindInFiles"];
	}
	
	return sharedController;
}

- (id) initWithWindowNibName: (NSString*) nibName {
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

	[auxView release];
	
	[findAllResults release];
	[findIdentifier release];
    [findInFiles release];
	
	// Finish up
	[super dealloc];
}

// = Updating the history =

- (void) addPhraseToFindHistory: (NSString*) phrase {
	phrase = [[phrase copy] autorelease];
	
	// Ensure that we don't store a duplicate copy of the phrase
	int lastIndex = [findHistory indexOfObject: phrase];
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
	[[NSUserDefaults standardUserDefaults] setObject: [[findHistory copy] autorelease]
											  forKey: IFFindHistoryPref];
	
	// Update the combo box
	[findPhrase reloadData];
}

- (void) addPhraseToReplaceHistory: (NSString*) phrase {
	phrase = [[phrase copy] autorelease];
	
	// Ensure that we don't store a duplicate copy of the phrase
	int lastIndex = [replaceHistory indexOfObject: phrase];
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
	[[NSUserDefaults standardUserDefaults] setObject: [[replaceHistory copy] autorelease]
											  forKey: IFReplaceHistoryPref];
	
	// Update the combo box
	[replacePhrase reloadData];
}

// = Actions =

- (IFFindType) currentFindType {
	NSMenuItem* selected = [searchType selectedItem];
	
	IFFindType flags = IFFindInvalidType;
	if ([ignoreCase state] == NSOnState) flags |= IFFindCaseInsensitive;
	
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
    if( [findInSource state] == NSOnState )                   locations |= IFFindSource;
    if( [findInExtensions state] == NSOnState )               locations |= IFFindExtensions;
    if( [findInDocumentationBasic state] == NSOnState )       locations |= IFFindDocumentationBasic;
    if( [findInDocumentationSource state] == NSOnState )      locations |= IFFindDocumentationSource;
    if( [findInDocumentationDefinitions state] == NSOnState ) locations |= IFFindDocumentationDefinitions;
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
}

- (void) showWindow:(id)sender {
	// Standard behaviour
	[super showWindow: sender];

	// Set the first responder
	[[self window] makeFirstResponder: findPhrase];
}

- (void) resizeToFitResults {
    // Calculate new height of table based on the number of results we have.
    float newTableHeight = MIN(20,findAllResults.count) * (findAllTable.rowHeight+findAllTable.intercellSpacing.height);

    NSRect windowFrame = self.window.frame;                     // Get current height of window
    float newHeight = borders + newTableHeight;                 // Calculate new height of window
    float delta = newHeight - windowFrame.size.height;          // Find out the difference
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
    NSDisableScreenUpdates();

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
    NSEnableScreenUpdates();
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
    [ignoreCase setState: (aType & IFFindCaseInsensitive) ? NSOnState : NSOffState];
    switch ( aType ) {
        case IFFindContains:     [searchType selectItem: containsItem]; break;
        case IFFindBeginsWith:   [searchType selectItem: beginsWithItem]; break;
        case IFFindCompleteWord: [searchType selectItem: completeWordItem]; break;
        case IFFindRegexp:       [searchType selectItem: regexpItem]; break;
        default:                 [searchType selectItem: containsItem]; break;
    }

    [findInSource                   setState: (aLocationType & IFFindSource)                   ? NSOnState : NSOffState];
    [findInExtensions               setState: (aLocationType & IFFindExtensions)               ? NSOnState : NSOffState];
    [findInDocumentationBasic       setState: (aLocationType & IFFindDocumentationBasic)       ? NSOnState : NSOffState];
    [findInDocumentationSource      setState: (aLocationType & IFFindDocumentationSource)      ? NSOnState : NSOffState];
    [findInDocumentationDefinitions setState: (aLocationType & IFFindDocumentationDefinitions) ? NSOnState : NSOffState];

    [self findTypeChanged: self];
    [self updateControls];

    // Start the find in files
    [self findAll: self];
}


- (IBAction) findAll: (id) sender {
	// Add the find phrase to the history
	[self addPhraseToFindHistory: [findPhrase stringValue]];

	// Create a new find identifier
	[findIdentifier autorelease];
	findAllCount++;
	findIdentifier = [[NSNumber alloc] initWithInt: findAllCount];
	
	// Clear out the find results
	[findAllResults release];
	findAllResults = nil;

	// Show progress
    [findProgress setHidden: NO];
    [findProgress setDisplayedWhenStopped:NO];
    [findProgress setMinValue:0.0f];
    [findProgress setMaxValue:1.0f];
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
            float progress = (float) num / (float) total;
            [findProgress setDoubleValue:progress];

            @synchronized([findInFiles searchResultsLock])
            {
                // Update results
                if( [findInFiles resultsCount] != [findAllResults count] ) {
                    NSArray* results = [findInFiles results];
                    findAllResults = [results retain];
                    [self updateFindAllResults];
                }

                // Have we finished?
                if( num == total ) {
                    // Stop the progress indicator
                    [findProgress stopAnimation: self];
                    [findProgress setHidden: YES];
                    
                    // Update the results.
                    [self updateFindAllResults];
                }
            }
        }
    ];
}

// = Performing 'replace all' =

- (IBAction) replaceAll: (id) sender {
    // TODO!
}


// = The find all table =

- (int)numberOfRowsInTableView: (NSTableView*) aTableView {
	return [findAllResults count];
}

- (id)				tableView: (NSTableView*) aTableView 
	objectValueForTableColumn: (NSTableColumn*) aTableColumn
					row: (int) rowIndex {
    NSAssert(rowIndex < [findAllResults count], @"Table display error");
    if( rowIndex >= [findAllResults count] ) {
        return nil;
    }
	NSString* ident = [aTableColumn identifier];
	IFFindResult* row = [findAllResults objectAtIndex: rowIndex];
	
	if ([ident isEqualToString: @"location"]) {
        return [self locationNameFromResult:row];
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

- (BOOL)                        tableView:(NSTableView *)tableView
    shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn
                                      row:(NSInteger)row {
    // Turn off expansion tooltips
    return NO;
}

- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)rowIndex {
    NSAssert(rowIndex < [findAllResults count], @"Table display error");
    if( rowIndex >= [findAllResults count] ) {
        return;
    }

    IFFindResult* row = [findAllResults objectAtIndex: rowIndex];
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

- (void)tableView:(NSTableView *)tableView didClickRow:(NSInteger)rowIndex {
	IFFindResult* row = [findAllResults objectAtIndex: rowIndex];
    
    NSString* anchorTag = @"";
    if( [[row definitionAnchorTag] length] > 0 ) {
        anchorTag = [row definitionAnchorTag];
    } else if ( [[row codeAnchorTag] length] > 0 ) {
        anchorTag = [row codeAnchorTag];
    } else if ( [[row exampleAnchorTag] length] > 0 ) {
        anchorTag = [row exampleAnchorTag];
    }
    
    //NSLog(@"tag is %@", anchorTag);
    [controller searchSelectedItemAtLocation: [row fileRange].location
                                      phrase: [row phrase]
                                      inFile: [row filepath]
                                        type: [row locationType]
                                   anchorTag: anchorTag];
}


// = Find/replace history =

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
		return [itemArray objectAtIndex: index];
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
		return [itemArray count];
	}
}

// = The auxiliary view =

- (void) showAuxiliaryView: (NSView*) newAuxView {
	// Do nothing if the aux view hasn't changed
	if (newAuxView == auxView) return;
	
	// Hide the old auxiliary view
	if (auxView) {
        [auxView removeFromSuperview];
		[auxView autorelease];
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

	float heightDiff		= (winFrame.size.height + auxFrame.size.height) - newWinFrame.size.height;
	newWinFrame.size.height += heightDiff;
	newWinFrame.origin.y	-= heightDiff;

    [[self window] setFrame:newWinFrame display:YES];
	
	// Add the new view
	if (newAuxView) {
		auxView		= [newAuxView retain];

		auxFrame.origin		= NSMakePoint(0, NSMaxY(auxViewPanel.bounds)-auxFrame.size.height);
		auxFrame.size.width = [[[self window] contentView] frame].size.width;
		[newAuxView setFrame: auxFrame];

        [newAuxView removeFromSuperview];
        [auxViewPanel addSubview:newAuxView];
	}
}

// = Combo box delegate methods =

- (void) comboBoxEnterKeyPress: (id) sender {
	if (sender == findPhrase) {
		[self findAll: self];
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
    if( aNotification.object == findPhrase ) {
        [self updateControls];
    }
}

// = Window delegate methods =
- (void) windowWillClose: (NSNotification*) notification {
    NSWindow *win = [notification object];
    
    if( win == findInFilesWindow ) {
        // Clear the find all results
        [findAllResults release];
        findAllResults = nil;
        [self showAuxiliaryView: nil];
        [win saveFrameUsingName:@"FindInFilesFrame"];
    }
}

@end
