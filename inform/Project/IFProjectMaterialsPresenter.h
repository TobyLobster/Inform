//
//  IFProjectMaterialsPresenter.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

@interface IFProjectMaterialsPresenter : NSObject<NSFilePresenter> {
    NSURL* primaryURL;
    NSURL* secondaryURL;
    NSURL* moveURL;
    
    NSOperationQueue* queue;
}

- (id) initWithURL:(NSURL*) mainURL;

- (NSURL *) presentedItemURL;
- (NSOperationQueue *) presentedItemOperationQueue;
- (NSURL *) primaryPresentedItemURL;


@end
