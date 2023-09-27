//
//  IFIndexPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <WebKit/WebKit.h>
#import <Cocoa/Cocoa.h>
#import "IFPage.h"

typedef NS_ENUM(int, IFIndexTabType) {
    IFIndexWelcome      = 1,
	IFIndexContents     = 2,
	IFIndexActions      = 3,
	IFIndexKinds        = 4,
	IFIndexPhrasebook   = 5,
	IFIndexRules        = 6,
	IFIndexScenes       = 7,
	IFIndexWorld        = 8,
};

@class IFProjectPane;

///
/// The 'Index' page
///
@interface IFIndexPage : IFPage<WKNavigationDelegate>

// The index view
/// \c YES if the index tab is available
@property (atomic, readonly) BOOL indexAvailable;

/// Updates the index view with the current files in the index subdirectory
- (void) updateIndexView;
/// Returns \c YES if we can select a specific tab in the index pane
- (BOOL) canSelectIndexTab: (int) whichTab;
/// Chooses a specific tab
- (void) switchToTab: (int) tabIdentifier;
/// Switches to the page specified by the given cell
- (IBAction) switchToCell: (id) sender;

- (instancetype) initWithProjectController: (IFProjectController*) controller withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

@end
