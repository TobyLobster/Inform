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
- (instancetype) initWithURL:(nullable NSURL*) mainURL NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
