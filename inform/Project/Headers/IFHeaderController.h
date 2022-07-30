//
//  IFHeaderController.h
//  Inform
//
//  Created by Andrew Hunter on 19/12/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IFHeader.h"

NS_ASSUME_NONNULL_BEGIN

@class IFHeaderController;
@class IFSyntaxTypes;
@class IFIntelFile;

///
/// Protocol that anything that can be a header view should implement
///
NS_SWIFT_NAME(IFHeaderViewProtocol)
@protocol IFHeaderView <NSObject>

@optional

/// Request to refresh all of the headers being managed by a view
- (void) refreshHeaders: (IFHeaderController*) controller;
/// Request to update the currently selected header
- (void) setSelectedHeader: (IFHeader*) selectedHeader
				controller: (IFHeaderController*) controller;

@end

///
/// Controller class used to manage the header view(s)
///
@interface IFHeaderController : NSObject

// Managing the list of headers

/// Updates the headers being managed by this controller from the specified intelligence object
- (void) updateFromIntelligence: (IFIntelFile*) intel;
/// The root header for this controller (ie, the header that the view should display at the top level)
@property (atomic, readonly, strong) IFHeader *rootHeader;
/// The currently selected header for this controller (or nil)
@property (atomic, readonly, strong, nullable) IFHeader *selectedHeader;
/// The intel file that is in use by this controller
@property (atomic, readonly, strong) IFIntelFile *intelFile;

// Managing the views being controlled

/// Adds a new header view to the list being managed by this object
- (void) addHeaderView: (NSView<IFHeaderView>*) newHeaderView;
/// Removes a header view from the list of headings being managed by this object
- (void) removeHeaderView: (NSView<IFHeaderView>*) oldHeaderView;

@end

NS_ASSUME_NONNULL_END
