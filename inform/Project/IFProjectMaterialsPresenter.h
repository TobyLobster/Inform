//
//  IFProjectMaterialsPresenter.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

@interface IFProjectMaterialsPresenter : NSObject<NSFilePresenter>

@property (atomic, readonly, copy)    NSURL *             presentedItemURL;
@property (atomic, readonly, strong)  NSOperationQueue *  presentedItemOperationQueue;
@property (atomic, readonly, copy)    NSURL *             primaryPresentedItemURL;

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithURL:(NSURL*) mainURL NS_DESIGNATED_INITIALIZER;

@end
