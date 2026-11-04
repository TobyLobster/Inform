//
//  IFFindInFilesController.h
//  Inform
//
//  Created by Andrew Hunter on 05/02/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFFindResult.h"
#import "Inform-Swift.h"

@class IFProject;
@class IFFindInFiles;
@class IFProjectController;

///
/// Controller for the find window
///
@interface IFFindInFilesController : NSWindowController <IFFindClickableTableViewDelegate>

// Initialisation

/// The shared find window controller
+ (IFFindInFilesController*) sharedFindInFilesController;

/// Set the project to use for the current search
-(void) setProject: (IFProject*) aProject;
- (void) setController: (IFProjectController*) aController;

// Actions
/// 'Find all' clicked
- (IBAction) findAll: (id) sender;
/// 'Replace all' clicked
- (IBAction) replaceAll: (id) sender;
/// The user has selected a new type of find (from contains, etc)
- (IBAction) findTypeChanged: (id) sender;
/// The user hit enter in the 'find' combo box
- (IBAction) comboBoxEnterKeyPress: (id) sender;

- (void) showFindInFilesWindow: (IFProjectController*) aController;     //
- (void) startFindInFilesSearchWithPhrase: (NSString*) aPhrase
                         withLocationType: (IFFindLocation) aLocationType
                                 withType: (IFFindType) aType;

@end

///
/// Delegate methods that can be used to enhance the find dialog (or provide it for new views or controllers)
///
@protocol IFFindInFilesDelegate <NSObject>
@optional

/// Allows delegates to specify which type of file they can search on
- (BOOL) canUseFindType: (IFFindType) find;

// 'Find all'
/// Should return an array of IFFindResults, used to implement 'Find All'
- (NSArray<IFFindResult*>*) findAllMatches: (NSString*) match
                                    ofType: (IFFindType) type
                                inLocation: (IFFindLocation) location
                   inFindInFilesController: (IFFindInFilesController*) controller
                            withIdentifier: (id) identifier;
/// The user has selected a find result, which should now be displayed
- (void) highlightFindResult: (IFFindResult*) result;

// 'Replace all'
/// Indicates that a replace all operation is starting
- (void) beginReplaceAll: (IFFindInFilesController*) sender;
/// Request to replace a find all result as part of a replace all operation
- (IFFindResult*) replaceFindAllResult: (IFFindResult*) result
							withString: (NSString*) replacement
								offset: (int*) offset;
/// The replace all operation has finished
- (void) finishedReplaceAll: (IFFindInFilesController*) sender;

@end
