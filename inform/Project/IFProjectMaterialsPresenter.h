//
//  IFProjectMaterialsPresenter.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface IFProjectMaterialsPresenter : NSObject<NSFilePresenter>

// The URLs are nil if the project's URL isn't a file URL
@property (atomic, readonly, copy, nullable)    NSURL *             presentedItemURL;
@property (atomic, readonly, strong)            NSOperationQueue *  presentedItemOperationQueue;
@property (atomic, readonly, copy, nullable)    NSURL *             primaryPresentedItemURL;

- (instancetype) init NS_UNAVAILABLE;
/// Creates the materials folder if it isn't there, telling the user if it moved an old one
- (instancetype) initWithURL:(nullable NSURL*) mainURL NS_DESIGNATED_INITIALIZER NS_SWIFT_UI_ACTOR;

/// Stops presenting the materials folder. NSFileCoordinator keeps the presenters it has alive, so
/// this must be called before letting go of one.
- (void) close;

@end

NS_ASSUME_NONNULL_END
