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

NS_ASSUME_NONNULL_BEGIN

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
/// Updates the index view with the current files in the index subdirectory
- (void) updateIndexView;
/// Returns \c YES if we can select a specific tab in the index pane
- (BOOL) canSelectIndexTab: (int) whichTab;
/// Chooses a specific tab
- (void) switchToTab: (int) tabIdentifier;
/// Opens a URL from the history, without recording it in the history again
- (void) openHistoricalURL: (nullable NSURL*) url;

- (instancetype) initWithProjectController: (IFProjectController*) controller withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
