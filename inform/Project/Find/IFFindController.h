//
//  IFFindController.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"

///
/// Controller for the find window
///
@interface IFFindController : NSWindowController

// Initialisation

+ (IFFindController*) sharedFindController;								// The shared find window controller

// Actions
- (IBAction) findNext: (id) sender;										// 'Next' clicked
- (IBAction) findPrevious: (id) sender;									// 'Previous' clicked
- (IBAction) replaceAndFind: (id) sender;								// 'Replace and find' clicked
- (IBAction) replace: (id) sender;										// 'Replace' clicked
- (IBAction) findAll: (id) sender;										// 'Find all' clicked
- (IBAction) replaceAll: (id) sender;									// 'Replace all' clicked
- (IBAction) useSelectionForFind: (id) sender;							// 'Use selection for find' chosen from the menu
- (IBAction) findTypeChanged: (id) sender;								// The user has selected a new type of find (from contains, etc)
- (IBAction) comboBoxEnterKeyPress: (id) sender;						// The user hit enter in the 'find all' combo box


// Menu actions
- (BOOL) canFindAgain: (id) sender;										// YES if find next/previous can be sensibly repeated
- (BOOL) canUseSelectionForFind: (id) sender;							// YES if 'useSelectionForFind' will work

// Updating the find window
- (void) updateFromFirstResponder;										// Updates the status of the find window from the first responder

- (void) showAuxiliaryView: (NSView*) auxView;							// Shows the specified auxiliary view in the find window

@end

///
/// Delegate methods that can be used to enhance the find dialog (or provide it for new views or controllers)
///
@protocol IFFindDelegate <NSObject>

// Basic interface (all searchable objects must implement this)
/// Request to find the next match
- (BOOL) findNextMatch:	(NSString*) match
				ofType: (IFFindType) type
     completionHandler: (void (^)(bool result))completionHandler;
@optional

/// Request to find the previous match
- (BOOL) findPreviousMatch: (NSString*) match
					ofType: (IFFindType) type
         completionHandler: (void (^)(bool result))completionHandler;

/// Allows delegates to specify which type of file they can search on
- (BOOL) canUseFindType: (IFFindType) find;

/// Returns whatever was currently selected: used to implement the 'use selection for find' menu option
- (void) currentSelectionForFindWithCompletionHandler:(void (^)(NSString* result))completionHandler;

// 'Find all'
/// Should return an array of IFFindResults
- (NSArray<IFFindResult*>*) findAllMatches: (NSString*) match
                                    ofType: (IFFindType) type
                                inLocation: (IFFindLocation) location
                          inFindController: (IFFindController*) controller
                            withIdentifier: (id) identifier;
/// The user has selected a find result, which should now be displayed
- (void) highlightFindResult: (IFFindResult*) result;

// Replace
/// Should replace the last found item with the specified text (or the currently selected item, if the user has manually changed the selection)
- (void) replaceFoundWith: (NSString*) match;
/// Indicates that a replace all operation is starting
- (void) beginReplaceAll: (IFFindController*) sender;
/// Request to replace a find all result as part of a replace all operation
- (IFFindResult*) replaceFindAllResult: (IFFindResult*) result
							withString: (NSString*) replacement
								offset: (int*) offset;
/// The replace all operation has finished
- (void) finishedReplaceAll: (IFFindController*) sender;
/// returns an array of the groups found on the last regex search. Used in "Replace and Find" and "Replace"
@property (atomic, readonly, copy) NSArray *lastFoundGroups;

@end
