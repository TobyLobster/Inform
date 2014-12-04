//
//  IFFindInFilesController.h
//  Inform-xc2
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

@class IFProject;
@class IFFindInFiles;
@class IFProjectController;

///
/// Controller for the find window
///
@interface IFFindInFilesController : NSWindowController {
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
    float                   borders;

	// Auxiliary views
	NSView*                 auxView;									// The auxiliary view that is being displayed
	NSRect                  winFrame;									// The default window frame

    // Project we are going to search
    IFProject*                  project;                                // Project to search in
    IFProjectController*        controller;                             // Project controller to use
    IFFindInFiles*              findInFiles;                            // Object used to perform searching

	// The delegate
	id activeDelegate;													// The delegate that we've chosen to work with
}

// Initialisation

+ (IFFindInFilesController*) sharedFindInFilesController;				// The shared find window controller

-(void) setProject: (IFProject*) aProject;                              // Set the project to use for the current search
- (void) setController: (IFProjectController*) aController;

// Actions
- (IBAction) findAll: (id) sender;										// 'Find all' clicked
- (IBAction) replaceAll: (id) sender;									// 'Replace all' clicked
- (IBAction) findTypeChanged: (id) sender;								// The user has selected a new type of find (from contains, etc)
- (IBAction) comboBoxEnterKeyPress: (id) sender;						// The user hit enter in the 'find' combo box

- (void) showFindInFilesWindow: (IFProjectController*) aController;     //
- (void) startFindInFilesSearchWithPhrase: (NSString*) aPhrase
                         withLocationType: (IFFindLocation) aLocationType
                                 withType: (IFFindType) aType;

@end

///
/// Delegate methods that can be used to enhance the find dialog (or provide it for new views or controllers)
///
@interface NSObject(IFFindInFilesDelegate)

- (BOOL) canUseFindType: (IFFindType) find;								// Allows delegates to specify which type of file they can search on

// 'Find all'
- (NSArray*) findAllMatches: (NSString*) match							// Should return an array of IFFindResults, used to implement 'Find All'
					 ofType: (IFFindType) type
                 inLocation: (IFFindLocation) location
    inFindInFilesController: (IFFindInFilesController*) controller
			 withIdentifier: (id) identifier;
- (void) highlightFindResult: (IFFindResult*) result;					// The user has selected a find result, which should now be displayed

// 'Replace all'
- (void) beginReplaceAll: (IFFindInFilesController*) sender;			// Indicates that a replace all operation is starting
- (IFFindResult*) replaceFindAllResult: (IFFindResult*) result			// Request to replace a find all result as part of a replace all operation
							withString: (NSString*) replacement
								offset: (int*) offset;
- (void) finishedReplaceAll: (IFFindInFilesController*) sender;			// The replace all operation has finished

@end
