//
//  IFSkeinPage.h
//  Inform
//
//  Created by Andrew Hunter on 25/03/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IFPage.h"
#import <WebKit/WebKit.h>

@class IFSkeinView;

///
/// The 'skein' page
///
@interface IFSkeinPage : IFPage<NSSplitViewDelegate, WKNavigationDelegate>

/// The skein view
@property (atomic, readonly, strong) IFSkeinView *skeinView;

- (instancetype) initWithProjectController: (IFProjectController*) controller
                                  withPane: (IFProjectPane*) pane NS_DESIGNATED_INITIALIZER;

- (void) selectActiveSkeinItem;
-(BOOL) selectSkeinItemWithNodeId:(unsigned long) skeinItemNodeId;

@end
