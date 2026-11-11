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
@class IFIntelFile;

///
/// Protocol that anything that can be a header view should implement
///
NS_SWIFT_NAME(IFHeaderViewProtocol)
NS_SWIFT_UI_ACTOR
@protocol IFHeaderView <NSObject>

@optional

/// Request to refresh all of the headers being managed by a view
- (void) refreshHeaders: (IFHeaderController*) controller;

@end

///
/// Controller class used to manage the header view(s)
///
NS_SWIFT_UI_ACTOR
@interface IFHeaderController : NSObject

// Managing the list of headers

/// Updates the headers being managed by this controller from the specified intelligence object. With no
/// intelligence, or none with symbols, the headers stay as they were.
- (void) updateFromIntelligence: (nullable IFIntelFile*) intel;
/// The root header for this controller (ie, the header that the view should display at the top level), or nil
/// before there are any headers
@property (nonatomic, readonly, strong, nullable) IFHeader *rootHeader;
/// The intel file that is in use by this controller (nil before the first update, or if it was given none)
@property (nonatomic, readonly, strong, nullable) IFIntelFile *intelFile;

// Managing the views being controlled

/// Adds a new header view to the list being managed by this object
- (void) addHeaderView: (NSView<IFHeaderView>*) newHeaderView;
/// Removes a header view from the list of headings being managed by this object
- (void) removeHeaderView: (NSView<IFHeaderView>*) oldHeaderView;

@end

NS_ASSUME_NONNULL_END
