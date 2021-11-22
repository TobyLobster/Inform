//
//  IFHeaderPage.h
//  Inform
//
//  Created by Andrew Hunter on 02/01/2008.
//  Copyright 2008 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeaderView.h"

@protocol IFHeaderPageDelegate;

///
/// Controller object that manages the headers page
///
@interface IFHeaderPage : NSObject <IFHeaderViewDelegate>

// The controller and view

/// The main header page view
///
/// The view that should be used to display the headers being managed by this class
@property (atomic, readwrite, strong) IBOutlet NSView *pageView;
/// Header view
///
/// The header view that this object is managing
@property (nonatomic, readwrite, strong) IBOutlet IFHeaderView *headerView;
/// The header controller that this page is using
///
/// Specifies the header controller that should be used to manage updates to this page
@property (nonatomic, readwrite, strong) IFHeaderController *controller;
/// The delegate for this page object
@property (atomic, weak) id<IFHeaderPageDelegate> delegate;

// Choosing objects

/// Marks the specified node as being selected
- (void) selectNode: (IFHeaderNode*) node;
/// Sets the node with the specified lines as selected
- (void) highlightNodeWithLines: (NSRange) lines;

// UI actions

/// Message sent when the depth popup is changed
- (IBAction) updateDepthPopup: (id) sender;
@end

@protocol IFHeaderPageDelegate <NSObject, IFHeaderViewDelegate>
@optional

- (void) headerPage: (IFHeaderPage*) page
	  limitToHeader: (IFHeader*) header;

@end
