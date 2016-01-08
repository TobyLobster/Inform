//
//  IFFindInFilesController.h
//  Inform
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
@interface IFFindInFilesController : NSWindowController

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
