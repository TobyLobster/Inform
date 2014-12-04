//
//  ZoomConnector.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/08/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomView.h"
#import "ZoomProtocol.h"

// Class used to connect the server to the view

@interface ZoomConnector : NSObject<ZClient> {
	NSConnection* connection;
	NSMutableArray* waitingViews;
}

// Retrieving the shared connector
+ (ZoomConnector*) sharedConnector;

// Adding/removing views from the queue
- (void) addViewWaitingForServer: (ZoomView*) view;
- (void) removeView: (ZoomView*) view;

@end
